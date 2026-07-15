import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter as Router, Link, Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import { BarChart3, Boxes, Home, Inbox, Layers, LogOut, ShoppingBag, Users } from 'lucide-react';
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
  const login = async (email, password) => {
    const response = await fetch(`${API_URL}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
    const data = await readJson(response);
    if (!response.ok) throw new Error(data.message || data.error || 'Connexion impossible');
    if (!data.user?.roles?.includes('ROLE_ADMIN')) throw new Error('Accès admin requis');
    localStorage.setItem('cyna_admin_token', data.token);
    localStorage.setItem('cyna_admin_user', JSON.stringify(data.user));
    setUser(data.user);
  };
  const logout = () => { localStorage.removeItem('cyna_admin_token'); localStorage.removeItem('cyna_admin_user'); setUser(null); };
  return <AuthContext.Provider value={{ user, login, logout }}>{children}</AuthContext.Provider>;
}
function useAuth(){ return useContext(AuthContext); }

function App() {
  const { user, logout } = useAuth();
  if (!user) return <Login/>;
  return <div className="shell"><aside><h1>CYNA Admin</h1><Link to="/"><BarChart3/> Dashboard</Link><Link to="/products"><Boxes/> Produits</Link><Link to="/categories"><Layers/> Catégories</Link><Link to="/orders"><ShoppingBag/> Commandes</Link><Link to="/users"><Users/> Utilisateurs</Link><Link to="/messages"><Inbox/> Messages</Link><Link to="/home"><Home/> Accueil</Link><button onClick={logout}><LogOut size={16}/> Déconnexion</button></aside><main><Routes><Route path="/" element={<Dashboard/>}/><Route path="/products" element={<Products/>}/><Route path="/products/new" element={<ProductForm/>}/><Route path="/categories" element={<Categories/>}/><Route path="/orders" element={<Orders/>}/><Route path="/users" element={<UsersPage/>}/><Route path="/messages" element={<Messages/>}/><Route path="/home" element={<HomeCarousel/>}/><Route path="*" element={<Navigate to="/"/>}/></Routes></main></div>;
}

function Login() {
  const { login } = useAuth();
  const [form, setForm] = useState({ email: 'admin@cyna.local', password: 'Admin123!' });
  const [error, setError] = useState('');
  return <form className="login" onSubmit={async e => { e.preventDefault(); try { await login(form.email, form.password); } catch (err) { setError(err.message); } }}><h1>Back-office CYNA</h1><input value={form.email} onChange={e => setForm({ ...form, email: e.target.value })}/><input type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })}/>{error && <p className="error">{error}</p>}<button>Connexion admin</button></form>;
}

function Dashboard() {
  const [data, setData] = useState(null);
  useEffect(() => { api('/admin/dashboard').then(setData); }, []);
  if (!data) return <p>Chargement...</p>;
  const maxSales = Math.max(...data.sales7Days.map(d => Number(d.total)), 1);
  return <><h2>Dashboard ventes</h2><section className="kpis"><Kpi label="CA" value={`${data.revenue.toFixed(2)} €`}/><Kpi label="Commandes" value={data.orders}/><Kpi label="Panier moyen" value={`${data.averageCart.toFixed(2)} €`}/></section><h3>Ventes 7 derniers jours</h3><div className="bars">{data.sales7Days.map(d => <div className="barItem" key={d.day}><span style={{ height: `${Math.max(12, (Number(d.total) / maxSales) * 120)}px` }} title={`${d.day} ${d.total} €`}/><small>{new Date(d.day).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' })}</small></div>)}</div><h3>Ventes par catégorie</h3><Table rows={data.salesByCategory}/></>;
}
function Kpi({ label, value }) { return <article className="kpi"><span>{label}</span><strong>{value}</strong></article>; }

function Products() {
  const [rows, setRows] = useState([]);
  const [categories, setCategories] = useState([]);
  const reload = () => { api('/admin/products').then(d => setRows(d.items)); api('/admin/categories').then(d => setCategories(d.items)); };
  useEffect(reload, []);
  const remove = async id => { await api(`/admin/products/${id}`, { method: 'DELETE' }); reload(); };
  return <Crud title="Produits" rows={rows} fields={['id','name','category_name','monthly_price','active']} onDelete={remove} form={<ProductInline categories={categories} onDone={reload}/>}/>;
}
function ProductInline({ categories, onDone }) {
  const [f, setF] = useState({ name: '', categoryId: 1, monthlyPrice: 99, description: '' });
  return <form className="inline" onSubmit={async e => { e.preventDefault(); await api('/admin/products', { method: 'POST', body: JSON.stringify(f) }); onDone(); }}><input placeholder="Nom" onChange={e => setF({...f,name:e.target.value})}/><select onChange={e => setF({...f,categoryId:Number(e.target.value)})}>{categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}</select><input type="number" placeholder="Prix mensuel" onChange={e => setF({...f,monthlyPrice:Number(e.target.value)})}/><input placeholder="Description" onChange={e => setF({...f,description:e.target.value})}/><button>Créer</button></form>;
}
function ProductForm(){ return <Products/>; }

function Categories() {
  const [rows, setRows] = useState([]);
  const [name, setName] = useState('');
  const reload = () => api('/admin/categories').then(d => setRows(d.items));
  useEffect(reload, []);
  return <Crud title="Catégories" rows={rows} fields={['id','name','slug','active']} onDelete={async id => { await api(`/admin/categories/${id}`, { method:'DELETE' }); reload(); }} form={<form className="inline" onSubmit={async e => { e.preventDefault(); await api('/admin/categories', { method:'POST', body: JSON.stringify({ name }) }); setName(''); reload(); }}><input value={name} placeholder="Nom catégorie" onChange={e => setName(e.target.value)}/><button>Créer</button></form>}/>;
}

function Orders(){ const [rows,setRows]=useState([]); useEffect(()=>{api('/admin/orders').then(d=>setRows(d.items));},[]); return <Crud title="Commandes" rows={rows} fields={['id','email','status','total','created_at']}/>; }
function UsersPage(){ const [rows,setRows]=useState([]); useEffect(()=>{api('/admin/users').then(d=>setRows(d.items));},[]); return <Crud title="Utilisateurs" rows={rows} fields={['id','email','first_name','last_name','roles']}/>; }
function Messages(){ const [rows,setRows]=useState([]); useEffect(()=>{api('/admin/contact-messages').then(d=>setRows(d.items));},[]); return <Crud title="Messages contact" rows={rows} fields={['id','email','subject','status','created_at']}/>; }
function HomeCarousel() {
  const [rows, setRows] = useState([]);
  const reload = () => api('/admin/home-carousel').then(d => setRows(d.items));
  useEffect(reload, []);
  const remove = async id => { await api(`/admin/home-carousel/${id}`, { method: 'DELETE' }); reload(); };
  return <Crud title="Page d'accueil - Carrousel" rows={rows} fields={['id','title','position','active']} onDelete={remove} form={<HomeCarouselInline onDone={reload}/>}/>;
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

function Crud({ title, rows, fields, onDelete, form }) {
  const [q, setQ] = useState('');
  const [page, setPage] = useState(1);
  const filtered = useMemo(() => rows.filter(r => JSON.stringify(r).toLowerCase().includes(q.toLowerCase())), [rows, q]);
  const visible = filtered.slice((page - 1) * 8, page * 8);
  return <><div className="top"><h2>{title}</h2><input placeholder="Rechercher" value={q} onChange={e => setQ(e.target.value)}/></div>{form}<table><thead><tr>{fields.map(f => <th key={f}>{f}</th>)}{onDelete && <th>Actions</th>}</tr></thead><tbody>{visible.map(row => <tr key={row.id}>{fields.map(f => <td key={f}>{String(row[f] ?? '')}</td>)}{onDelete && <td><button onClick={() => onDelete(row.id)}>Supprimer</button></td>}</tr>)}</tbody></table><div className="pager"><button disabled={page===1} onClick={()=>setPage(page-1)}>Précédent</button><span>{page}</span><button disabled={page*8>=filtered.length} onClick={()=>setPage(page+1)}>Suivant</button></div></>;
}

function Table({ rows }) {
  if (!rows?.length) return null;
  const fields = Object.keys(rows[0]);
  return <table><tbody>{rows.map((r,i)=><tr key={i}>{fields.map(f=><td key={f}>{r[f]}</td>)}</tr>)}</tbody></table>;
}

createRoot(document.getElementById('root')).render(<Router><AuthProvider><App/></AuthProvider></Router>);
