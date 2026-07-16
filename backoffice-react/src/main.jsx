import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter as Router, Link, Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import { ArrowDown, ArrowUp, BarChart3, Boxes, Home, Inbox, Layers, LogOut, MessageSquare, Pencil, ShoppingBag, Star, Type, Users } from 'lucide-react';
import './styles.css';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api';
const AuthContext = createContext(null);

async function api(path, options = {}) {
  const token = localStorage.getItem('cyna_admin_token');
  const res = await fetch(`${API_URL}${path}`, { ...options, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(options.headers || {}) } });
  if (res.status === 401) {
    // Le token JWT admin expire après 1h. Sans ça, chaque appel échouait en silence
    // et les pages restaient bloquées en "Chargement..." indéfiniment.
    localStorage.removeItem('cyna_admin_token');
    localStorage.removeItem('cyna_admin_user');
    window.location.reload();
    throw new Error('Session expirée, reconnexion nécessaire.');
  }
  const data = await readJson(res);
  if (!res.ok) throw new Error(data.message || data.error || 'Erreur API');
  return data;
}

async function readJson(response) {
  const text = await response.text();
  try {
    return text ? JSON.parse(text) : {};
  } catch {
    throw new Error(`L'API a renvoye du HTML au lieu du JSON. Verifie que Symfony tourne sur ${API_URL}.`);
  }
}

function AuthProvider({ children }) {
  const [user, setUser] = useState(JSON.parse(localStorage.getItem('cyna_admin_user') || 'null'));
  // Étape 1 : email + mot de passe → déclenche l'envoi du code 2FA (pas encore de jeton).
  const login = async (email, password) => {
    const response = await fetch(`${API_URL}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
    const data = await readJson(response);
    if (!response.ok) throw new Error(data.message || data.error || 'Connexion impossible');
    return data; // { status: '2fa_required', message }
  };
  // Étape 2 : code à 6 chiffres → jeton. Le rôle admin est vérifié ici.
  const verify2fa = async (email, code) => {
    const response = await fetch(`${API_URL}/auth/verify-2fa`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, code }) });
    const data = await readJson(response);
    if (!response.ok) throw new Error(data.message || data.error || 'Code invalide');
    if (!data.user?.roles?.includes('ROLE_ADMIN')) throw new Error('Accès admin requis');
    localStorage.setItem('cyna_admin_token', data.token);
    localStorage.setItem('cyna_admin_user', JSON.stringify(data.user));
    setUser(data.user);
  };
  const logout = () => { localStorage.removeItem('cyna_admin_token'); localStorage.removeItem('cyna_admin_user'); setUser(null); };
  return <AuthContext.Provider value={{ user, login, verify2fa, logout }}>{children}</AuthContext.Provider>;
}
function useAuth(){ return useContext(AuthContext); }

function App() {
  const { user, logout } = useAuth();
  if (!user) return <Login/>;
  return <div className="shell"><aside><h1>CYNA Admin</h1><Link to="/"><BarChart3/> Dashboard</Link><Link to="/products"><Boxes/> Produits</Link><Link to="/categories"><Layers/> Catégories</Link><Link to="/orders"><ShoppingBag/> Commandes</Link><Link to="/users"><Users/> Utilisateurs</Link><Link to="/messages"><Inbox/> Messages</Link><Link to="/home"><Home/> Carrousel</Link><Link to="/featured"><Star/> Top produits</Link><Link to="/texts"><Type/> Textes accueil</Link><Link to="/chatbot"><MessageSquare/> Chatbot</Link><button onClick={logout}><LogOut size={16}/> Déconnexion</button></aside><main><Routes><Route path="/" element={<Dashboard/>}/><Route path="/products" element={<Products/>}/><Route path="/products/new" element={<ProductForm/>}/><Route path="/categories" element={<Categories/>}/><Route path="/orders" element={<Orders/>}/><Route path="/users" element={<UsersPage/>}/><Route path="/messages" element={<Messages/>}/><Route path="/home" element={<HomeCarousel/>}/><Route path="/featured" element={<Featured/>}/><Route path="/texts" element={<HomeTexts/>}/><Route path="/chatbot" element={<ChatbotAdmin/>}/><Route path="*" element={<Navigate to="/"/>}/></Routes></main></div>;
}

function Login() {
  const { login, verify2fa } = useAuth();
  const [form, setForm] = useState({ email: 'admin@cyna.local', password: 'Admin123!' });
  const [step, setStep] = useState('credentials'); // 'credentials' → 'code'
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');

  const submitCredentials = async e => {
    e.preventDefault();
    setError('');
    try {
      const data = await login(form.email, form.password);
      setInfo(data.message);
      setStep('code');
    } catch (err) {
      setError(err.message);
    }
  };

  const submitCode = async e => {
    e.preventDefault();
    setError('');
    try {
      await verify2fa(form.email, code);
    } catch (err) {
      setError(err.message);
    }
  };

  if (step === 'code') {
    return (
      <form className="login" onSubmit={submitCode}>
        <h1>Vérification en deux étapes</h1>
        <p>{info}</p>
        {form.email.endsWith('.local') && (
          <p>Adresse de démo : le code est visible dans <a href="http://localhost:8025" target="_blank" rel="noreferrer">Mailpit</a>.</p>
        )}
        <input placeholder="Code à 6 chiffres" inputMode="numeric" autoFocus value={code} onChange={e => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}/>
        {error && <p className="error">{error}</p>}
        <button disabled={code.length !== 6}>Valider</button>
        <button type="button" onClick={submitCredentials}>Renvoyer un code</button>
        <button type="button" onClick={() => { setStep('credentials'); setCode(''); setError(''); }}>Retour</button>
      </form>
    );
  }

  return (
    <form className="login" onSubmit={submitCredentials}>
      <h1>Back-office CYNA</h1>
      <input value={form.email} onChange={e => setForm({ ...form, email: e.target.value })}/>
      <input type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })}/>
      {error && <p className="error">{error}</p>}
      <button>Connexion admin</button>
    </form>
  );
}

function Dashboard() {
  const [data, setData] = useState(null);
  useEffect(() => { api('/admin/dashboard').then(setData); }, []);
  if (!data) return <p>Chargement...</p>;
  const maxSales = Math.max(...data.sales7Days.map(d => Number(d.total)), 1);
  const avgDays = data.averageCart7Days || [];
  const maxAvg = Math.max(...avgDays.map(d => Number(d.average)), 1);
  return <><h2>Dashboard ventes</h2><section className="kpis"><Kpi label="CA" value={`${data.revenue.toFixed(2)} €`}/><Kpi label="Commandes" value={data.orders}/><Kpi label="Panier moyen" value={`${data.averageCart.toFixed(2)} €`}/></section>
    <h3>Ventes 7 derniers jours</h3>
    <div className="bars">{data.sales7Days.map(d => <div className="barItem" key={d.day}><span style={{ height: `${Math.max(12, (Number(d.total) / maxSales) * 120)}px` }} title={`${d.day} ${d.total} €`}/><small>{new Date(d.day).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' })}</small></div>)}</div>
    <h3>Panier moyen par jour</h3>
    {avgDays.length === 0 ? <p>Aucune commande sur les 7 derniers jours.</p> :
      <div className="bars">{avgDays.map(d => <div className="barItem" key={d.day}><span className="bar-alt" style={{ height: `${Math.max(12, (Number(d.average) / maxAvg) * 120)}px` }} title={`${d.day} ${Number(d.average).toFixed(2)} €`}/><small>{new Date(d.day).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' })}</small></div>)}</div>}
    <h3>Répartition des ventes par catégorie</h3>
    <div className="pie-wrap"><Pie rows={data.salesByCategory}/><Table rows={data.salesByCategory}/></div>
  </>;
}
function Kpi({ label, value }) { return <article className="kpi"><span>{label}</span><strong>{value}</strong></article>; }

// Camembert SVG sans dépendance : un secteur par catégorie.
const PIE_COLORS = ['#0b3a75', '#18a4bc', '#7c5cff', '#e8873a', '#b42318', '#2e7d32'];
function Pie({ rows }) {
  const total = rows.reduce((s, r) => s + Number(r.total), 0);
  if (!total) return null;
  let angle = -Math.PI / 2;
  const slices = rows.map((r, i) => {
    const share = Number(r.total) / total;
    const start = angle;
    angle += share * 2 * Math.PI;
    const large = share > 0.5 ? 1 : 0;
    const x1 = 90 + 80 * Math.cos(start), y1 = 90 + 80 * Math.sin(start);
    const x2 = 90 + 80 * Math.cos(angle), y2 = 90 + 80 * Math.sin(angle);
    const d = share >= 0.999
      ? 'M 90 10 A 80 80 0 1 1 89.99 10 Z'
      : `M 90 90 L ${x1} ${y1} A 80 80 0 ${large} 1 ${x2} ${y2} Z`;
    return { d, color: PIE_COLORS[i % PIE_COLORS.length], label: r.category, share };
  });
  return (
    <div className="pie">
      <svg viewBox="0 0 180 180" width="180" height="180">{slices.map(s => <path key={s.label} d={s.d} fill={s.color}><title>{`${s.label} : ${(s.share * 100).toFixed(1)} %`}</title></path>)}</svg>
      <ul>{slices.map(s => <li key={s.label}><i style={{ background: s.color }}/>{s.label} — {(s.share * 100).toFixed(1)} %</li>)}</ul>
    </div>
  );
}

function Products() {
  const [rows, setRows] = useState([]);
  const [categories, setCategories] = useState([]);
  const [editing, setEditing] = useState(null); // ligne en cours de modification
  const reload = () => { api('/admin/products').then(d => setRows(d.items)); api('/admin/categories').then(d => setCategories(d.items)); };
  useEffect(reload, []);
  const remove = async id => { await api(`/admin/products/${id}`, { method: 'DELETE' }); reload(); };
  return <Crud title="Produits" rows={rows} fields={['id','name','category_name','monthly_price','stock','active']} onDelete={remove} onEdit={setEditing}
    form={<ProductInline key={editing?.id || 'new'} categories={categories} editing={editing} onDone={() => { setEditing(null); reload(); }} onCancel={() => setEditing(null)}/>}/>;
}
function ProductInline({ categories, editing, onDone, onCancel }) {
  const [f, setF] = useState(editing ? {
    name: editing.name, categoryId: editing.category_id, monthlyPrice: Number(editing.monthly_price),
    stock: Number(editing.stock ?? 25), description: editing.description || '', technicalSpecs: editing.technical_specs || '',
  } : { name: '', categoryId: categories[0]?.id || 1, monthlyPrice: 99, stock: 25, description: '', technicalSpecs: '' });
  const submit = async e => {
    e.preventDefault();
    if (editing) await api(`/admin/products/${editing.id}`, { method: 'PATCH', body: JSON.stringify(f) });
    else await api('/admin/products', { method: 'POST', body: JSON.stringify(f) });
    onDone();
  };
  return <form className="inline" onSubmit={submit}>
    {editing && <strong>Modifier #{editing.id}</strong>}
    <input placeholder="Nom" value={f.name} onChange={e => setF({...f,name:e.target.value})}/>
    <select value={f.categoryId} onChange={e => setF({...f,categoryId:Number(e.target.value)})}>{categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}</select>
    <input type="number" step="0.01" placeholder="Prix mensuel" value={f.monthlyPrice} onChange={e => setF({...f,monthlyPrice:Number(e.target.value)})}/>
    <input type="number" placeholder="Stock" value={f.stock} onChange={e => setF({...f,stock:Number(e.target.value)})}/>
    <input placeholder="Description" value={f.description} onChange={e => setF({...f,description:e.target.value})}/>
    <input placeholder="Caractéristiques techniques (séparées par ·)" value={f.technicalSpecs} onChange={e => setF({...f,technicalSpecs:e.target.value})}/>
    <button>{editing ? 'Enregistrer' : 'Créer'}</button>
    {editing && <button type="button" onClick={onCancel}>Annuler</button>}
  </form>;
}
function ProductForm(){ return <Products/>; }

function Categories() {
  const [rows, setRows] = useState([]);
  const [editing, setEditing] = useState(null);
  const reload = () => api('/admin/categories').then(d => setRows(d.items));
  useEffect(reload, []);
  return <Crud title="Catégories" rows={rows} fields={['id','name','slug','image_url','active']} onEdit={setEditing}
    onDelete={async id => { await api(`/admin/categories/${id}`, { method:'DELETE' }); reload(); }}
    form={<CategoryInline key={editing?.id || 'new'} editing={editing} onDone={() => { setEditing(null); reload(); }} onCancel={() => setEditing(null)}/>}/>;
}
function CategoryInline({ editing, onDone, onCancel }) {
  const [f, setF] = useState(editing
    ? { name: editing.name, description: editing.description || '', imageUrl: editing.image_url || '' }
    : { name: '', description: '', imageUrl: '' });
  const submit = async e => {
    e.preventDefault();
    if (editing) await api(`/admin/categories/${editing.id}`, { method: 'PATCH', body: JSON.stringify(f) });
    else await api('/admin/categories', { method: 'POST', body: JSON.stringify(f) });
    onDone();
  };
  return <form className="inline" onSubmit={submit}>
    {editing && <strong>Modifier #{editing.id}</strong>}
    <input placeholder="Nom catégorie" value={f.name} onChange={e => setF({ ...f, name: e.target.value })}/>
    <input placeholder="Description" value={f.description} onChange={e => setF({ ...f, description: e.target.value })}/>
    <input placeholder="URL image" value={f.imageUrl} onChange={e => setF({ ...f, imageUrl: e.target.value })}/>
    <button>{editing ? 'Enregistrer' : 'Créer'}</button>
    {editing && <button type="button" onClick={onCancel}>Annuler</button>}
  </form>;
}

function Orders(){ const [rows,setRows]=useState([]); useEffect(()=>{api('/admin/orders').then(d=>setRows(d.items));},[]); return <Crud title="Commandes" rows={rows} fields={['id','email','status','total','created_at']}/>; }
function UsersPage(){ const [rows,setRows]=useState([]); useEffect(()=>{api('/admin/users').then(d=>setRows(d.items));},[]); return <Crud title="Utilisateurs" rows={rows} fields={['id','email','first_name','last_name','roles']}/>; }
function Messages(){ const [rows,setRows]=useState([]); useEffect(()=>{api('/admin/contact-messages').then(d=>setRows(d.items));},[]); return <Crud title="Messages contact" rows={rows} fields={['id','email','subject','status','created_at']}/>; }
function HomeCarousel() {
  const [rows, setRows] = useState([]);
  const reload = () => api('/admin/home-carousel').then(d => setRows(d.items));
  useEffect(reload, []);
  const remove = async id => { await api(`/admin/home-carousel/${id}`, { method: 'DELETE' }); reload(); };
  // Réordonner : échange les positions avec le voisin (cahier des charges "modifications ordre").
  const move = async (index, dir) => {
    const a = rows[index], b = rows[index + dir];
    if (!b) return;
    await api(`/admin/home-carousel/${a.id}`, { method: 'PATCH', body: JSON.stringify({ position: b.position }) });
    await api(`/admin/home-carousel/${b.id}`, { method: 'PATCH', body: JSON.stringify({ position: a.position }) });
    reload();
  };
  return <Crud title="Page d'accueil - Carrousel" rows={rows} fields={['id','title','position','active']} onDelete={remove}
    rowActions={(row, index) => <>
      <button title="Monter" disabled={index === 0} onClick={() => move(index, -1)}><ArrowUp size={14}/></button>
      <button title="Descendre" disabled={index === rows.length - 1} onClick={() => move(index, 1)}><ArrowDown size={14}/></button>
    </>}
    form={<HomeCarouselInline onDone={reload}/>}/>;
}

// Top produits de la page d'accueil : choix des produits mis en avant + ordre.
function Featured() {
  const [rows, setRows] = useState([]);
  const [products, setProducts] = useState([]);
  const [productId, setProductId] = useState('');
  const reload = () => { api('/admin/featured-products').then(d => setRows(d.items)); api('/admin/products').then(d => setProducts(d.items)); };
  useEffect(reload, []);
  const add = async e => {
    e.preventDefault();
    if (!productId) return;
    const maxPos = Math.max(0, ...rows.map(r => r.position));
    await api('/admin/featured-products', { method: 'POST', body: JSON.stringify({ productId: Number(productId), position: maxPos + 1 }) });
    setProductId('');
    reload();
  };
  const move = async (index, dir) => {
    const a = rows[index], b = rows[index + dir];
    if (!b) return;
    await api(`/admin/featured-products/${a.id}`, { method: 'PATCH', body: JSON.stringify({ position: b.position }) });
    await api(`/admin/featured-products/${b.id}`, { method: 'PATCH', body: JSON.stringify({ position: a.position }) });
    reload();
  };
  return <Crud title="Page d'accueil - Top produits" rows={rows} fields={['id','product_name','monthly_price','position']}
    onDelete={async id => { await api(`/admin/featured-products/${id}`, { method: 'DELETE' }); reload(); }}
    rowActions={(row, index) => <>
      <button title="Monter" disabled={index === 0} onClick={() => move(index, -1)}><ArrowUp size={14}/></button>
      <button title="Descendre" disabled={index === rows.length - 1} onClick={() => move(index, 1)}><ArrowDown size={14}/></button>
    </>}
    form={<form className="inline" onSubmit={add}>
      <select value={productId} onChange={e => setProductId(e.target.value)}>
        <option value="">Choisir un produit à mettre en avant...</option>
        {products.filter(p => !rows.some(r => r.product_id === p.id)).map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
      </select>
      <button>Ajouter</button>
    </form>}/>;
}

// Blocs de texte de la page d'accueil, entièrement éditables.
function HomeTexts() {
  const [rows, setRows] = useState([]);
  const [editing, setEditing] = useState(null);
  const reload = () => api('/admin/home-texts').then(d => setRows(d.items));
  useEffect(reload, []);
  return <Crud title="Page d'accueil - Textes" rows={rows} fields={['id','title','position','active']} onEdit={setEditing}
    onDelete={async id => { await api(`/admin/home-texts/${id}`, { method: 'DELETE' }); reload(); }}
    form={<HomeTextInline key={editing?.id || 'new'} editing={editing} onDone={() => { setEditing(null); reload(); }} onCancel={() => setEditing(null)}/>}/>;
}
function HomeTextInline({ editing, onDone, onCancel }) {
  const [f, setF] = useState(editing
    ? { title: editing.title, content: editing.content, position: editing.position }
    : { title: '', content: '', position: 0 });
  const submit = async e => {
    e.preventDefault();
    if (editing) await api(`/admin/home-texts/${editing.id}`, { method: 'PATCH', body: JSON.stringify(f) });
    else await api('/admin/home-texts', { method: 'POST', body: JSON.stringify(f) });
    onDone();
  };
  return <form className="inline" onSubmit={submit}>
    {editing && <strong>Modifier #{editing.id}</strong>}
    <input placeholder="Titre" value={f.title} onChange={e => setF({ ...f, title: e.target.value })}/>
    <input placeholder="Contenu" value={f.content} onChange={e => setF({ ...f, content: e.target.value })}/>
    <input type="number" placeholder="Position" value={f.position} onChange={e => setF({ ...f, position: Number(e.target.value) })}/>
    <button>{editing ? 'Enregistrer' : 'Ajouter'}</button>
    {editing && <button type="button" onClick={onCancel}>Annuler</button>}
  </form>;
}

// Réponses du chatbot de la page contact : mots-clés (séparés par des virgules) → réponse.
function ChatbotAdmin() {
  const [rows, setRows] = useState([]);
  const [editing, setEditing] = useState(null);
  const reload = () => api('/admin/chatbot').then(d => setRows(d.items));
  useEffect(reload, []);
  return <Crud title="Chatbot - Réponses" rows={rows} fields={['id','keywords','answer','active']} onEdit={setEditing}
    onDelete={async id => { await api(`/admin/chatbot/${id}`, { method: 'DELETE' }); reload(); }}
    form={<ChatbotInline key={editing?.id || 'new'} editing={editing} onDone={() => { setEditing(null); reload(); }} onCancel={() => setEditing(null)}/>}/>;
}
function ChatbotInline({ editing, onDone, onCancel }) {
  const [f, setF] = useState(editing
    ? { keywords: editing.keywords, answer: editing.answer }
    : { keywords: '', answer: '' });
  const submit = async e => {
    e.preventDefault();
    if (editing) await api(`/admin/chatbot/${editing.id}`, { method: 'PATCH', body: JSON.stringify(f) });
    else await api('/admin/chatbot', { method: 'POST', body: JSON.stringify(f) });
    onDone();
  };
  return <form className="inline" onSubmit={submit}>
    {editing && <strong>Modifier #{editing.id}</strong>}
    <input placeholder="Mots-clés (séparés par des virgules)" value={f.keywords} onChange={e => setF({ ...f, keywords: e.target.value })}/>
    <input placeholder="Réponse du bot" value={f.answer} onChange={e => setF({ ...f, answer: e.target.value })}/>
    <button>{editing ? 'Enregistrer' : 'Ajouter'}</button>
    {editing && <button type="button" onClick={onCancel}>Annuler</button>}
  </form>;
}
function HomeCarouselInline({ onDone }) {
  const [f, setF] = useState({ title: '', subtitle: '', imageUrl: '', ctaUrl: '/catalogue', position: 0 });
  return (
    <form className="inline" onSubmit={async e => { e.preventDefault(); await api('/admin/home-carousel', { method: 'POST', body: JSON.stringify(f) }); setF({ title: '', subtitle: '', imageUrl: '', ctaUrl: '/catalogue', position: 0 }); onDone(); }}>
      <input placeholder="Titre" value={f.title} onChange={e => setF({ ...f, title: e.target.value })}/>
      <input placeholder="Sous-titre" value={f.subtitle} onChange={e => setF({ ...f, subtitle: e.target.value })}/>
      <input placeholder="URL image" value={f.imageUrl} onChange={e => setF({ ...f, imageUrl: e.target.value })}/>
      <input placeholder="Lien (ex: /catalogue)" value={f.ctaUrl} onChange={e => setF({ ...f, ctaUrl: e.target.value })}/>
      <input type="number" placeholder="Position" value={f.position} onChange={e => setF({ ...f, position: Number(e.target.value) })}/>
      <button>Ajouter</button>
    </form>
  );
}

function Crud({ title, rows, fields, onDelete, onEdit, rowActions, form }) {
  const [q, setQ] = useState('');
  const [page, setPage] = useState(1);
  const filtered = useMemo(() => rows.filter(r => JSON.stringify(r).toLowerCase().includes(q.toLowerCase())), [rows, q]);
  const visible = filtered.slice((page - 1) * 8, page * 8);
  const hasActions = onDelete || onEdit || rowActions;
  return <><div className="top"><h2>{title}</h2><input placeholder="Rechercher" value={q} onChange={e => setQ(e.target.value)}/></div>{form}<table><thead><tr>{fields.map(f => <th key={f}>{f}</th>)}{hasActions && <th>Actions</th>}</tr></thead><tbody>{visible.map((row, index) => <tr key={row.id}>{fields.map(f => <td key={f}>{String(row[f] ?? '')}</td>)}{hasActions && <td className="actions">{rowActions && rowActions(row, (page - 1) * 8 + index)}{onEdit && <button onClick={() => onEdit(row)}><Pencil size={14}/> Modifier</button>}{onDelete && <button onClick={() => onDelete(row.id)}>Supprimer</button>}</td>}</tr>)}</tbody></table><div className="pager"><button disabled={page===1} onClick={()=>setPage(page-1)}>Précédent</button><span>{page}</span><button disabled={page*8>=filtered.length} onClick={()=>setPage(page+1)}>Suivant</button></div></>;
}

function Table({ rows }) {
  if (!rows?.length) return null;
  const fields = Object.keys(rows[0]);
  return <table><tbody>{rows.map((r,i)=><tr key={i}>{fields.map(f=><td key={f}>{r[f]}</td>)}</tr>)}</tbody></table>;
}

createRoot(document.getElementById('root')).render(<Router><AuthProvider><App/></AuthProvider></Router>);
