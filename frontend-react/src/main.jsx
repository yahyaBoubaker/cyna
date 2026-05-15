import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Link, Navigate, Route, BrowserRouter as Router, Routes, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { Shield, ShoppingCart, User, Search, LogOut } from 'lucide-react';
import './styles.css';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api';
const AuthContext = createContext(null);

async function api(path, options = {}) {
  const token = localStorage.getItem('cyna_token');
  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {}),
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.message || data.error || 'Erreur API');
  return data;
}

function AuthProvider({ children }) {
  const [user, setUser] = useState(JSON.parse(localStorage.getItem('cyna_user') || 'null'));
  const login = async (email, password) => {
    const data = await api('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) });
    localStorage.setItem('cyna_token', data.token);
    localStorage.setItem('cyna_user', JSON.stringify(data.user));
    setUser(data.user);
  };
  const register = async (payload) => {
    const data = await api('/auth/register', { method: 'POST', body: JSON.stringify(payload) });
    localStorage.setItem('cyna_token', data.token);
    localStorage.setItem('cyna_user', JSON.stringify(data.user));
    setUser(data.user);
  };
  const logout = () => {
    localStorage.removeItem('cyna_token');
    localStorage.removeItem('cyna_user');
    setUser(null);
  };
  return <AuthContext.Provider value={{ user, login, register, logout }}>{children}</AuthContext.Provider>;
}

function useAuth() { return useContext(AuthContext); }
function cartItems() { return JSON.parse(localStorage.getItem('cyna_cart') || '[]'); }
function saveCart(items) { localStorage.setItem('cyna_cart', JSON.stringify(items)); window.dispatchEvent(new Event('cart')); }

function Layout() {
  const { user, logout } = useAuth();
  const [count, setCount] = useState(cartItems().length);
  useEffect(() => {
    const onCart = () => setCount(cartItems().length);
    window.addEventListener('cart', onCart);
    return () => window.removeEventListener('cart', onCart);
  }, []);
  return <><header><Link className="brand" to="/"><Shield/> CYNA</Link><nav><Link to="/catalogue">Catalogue</Link><Link to="/contact">Contact</Link><Link to="/panier"><ShoppingCart/> {count}</Link>{user ? <><Link to="/compte"><User/> {user.firstName || 'Compte'}</Link><button onClick={logout}><LogOut size={16}/> Quitter</button></> : <Link to="/login">Connexion</Link>}</nav></header><main><Routes><Route path="/" element={<Home/>}/><Route path="/catalogue" element={<Catalogue/>}/><Route path="/categorie/:id" element={<Category/>}/><Route path="/recherche" element={<SearchPage/>}/><Route path="/produits/:id" element={<ProductDetail/>}/><Route path="/panier" element={<Cart/>}/><Route path="/checkout" element={<Protected><Checkout/></Protected>}/><Route path="/login" element={<Login/>}/><Route path="/register" element={<Register/>}/><Route path="/mot-de-passe-oublie" element={<Forgot/>}/><Route path="/compte" element={<Protected><Account/></Protected>}/><Route path="/commandes" element={<Protected><Orders/></Protected>}/><Route path="/commandes/:id" element={<Protected><OrderDetail/></Protected>}/><Route path="/contact" element={<Contact/>}/></Routes></main><footer>CYNA - SaaS cybersecurity commerce</footer></>;
}

function Protected({ children }) {
  return useAuth().user ? children : <Navigate to="/login"/>;
}

function Home() {
  return <section className="hero"><div><p className="eyebrow">SOC - EDR - XDR</p><h1>CYNA Cybersecurity SaaS</h1><p>Des services cyber managés pour protéger les entreprises avec une plateforme claire, mesurable et prête pour l'abonnement.</p><Link className="primary" to="/catalogue">Voir les services</Link></div></section>;
}

function Catalogue() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  useEffect(() => { api('/products').then(d => setProducts(d.items)); api('/categories').then(d => setCategories(d.items)); }, []);
  return <><Toolbar categories={categories}/><ProductGrid products={products}/></>;
}

function Category() {
  const { id } = useParams();
  const [products, setProducts] = useState([]);
  useEffect(() => { api(`/categories/${id}/products`).then(d => setProducts(d.items)); }, [id]);
  return <><h1>Catégorie</h1><ProductGrid products={products}/></>;
}

function SearchPage() {
  const [params] = useSearchParams();
  const [products, setProducts] = useState([]);
  useEffect(() => { api(`/search?q=${encodeURIComponent(params.get('q') || '')}`).then(d => setProducts(d.items)); }, [params]);
  return <><h1>Recherche</h1><ProductGrid products={products}/></>;
}

function Toolbar({ categories }) {
  const [q, setQ] = useState('');
  const navigate = useNavigate();
  return <section className="toolbar"><form onSubmit={e => { e.preventDefault(); navigate(`/recherche?q=${encodeURIComponent(q)}`); }}><Search/><input value={q} onChange={e => setQ(e.target.value)} placeholder="Rechercher SOC, EDR, XDR..."/></form><div>{categories.map(c => <Link key={c.id} to={`/categorie/${c.id}`}>{c.name}</Link>)}</div></section>;
}

function ProductGrid({ products }) {
  return <section className="grid">{products.map(p => <article className="card" key={p.id}><img src={p.image_url || 'https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&w=900&q=80'} alt=""/><div><p className="eyebrow">{p.category_name}</p><h2>{p.name}</h2><p>{p.description}</p><strong>{Number(p.monthly_price).toFixed(2)} €/mois</strong><Link className="primary" to={`/produits/${p.id}`}>Détail</Link></div></article>)}</section>;
}

function ProductDetail() {
  const { id } = useParams();
  const [p, setP] = useState(null);
  const [duration, setDuration] = useState(12);
  useEffect(() => { api(`/products/${id}`).then(setP); }, [id]);
  if (!p) return <p>Chargement...</p>;
  const add = () => { const items = cartItems(); items.push({ productId: p.id, name: p.name, monthlyPrice: Number(p.monthly_price), quantity: 1, durationMonths: duration }); saveCart(items); };
  return <section className="detail"><img src={p.images?.[0]?.url} alt=""/><div><p className="eyebrow">{p.category_name}</p><h1>{p.name}</h1><p>{p.description}</p><label>Durée<select value={duration} onChange={e => setDuration(Number(e.target.value))}><option value="1">1 mois</option><option value="12">12 mois</option><option value="24">24 mois</option></select></label><strong>{(Number(p.monthly_price) * duration).toFixed(2)} €</strong><button className="primary" onClick={add}>Ajouter au panier</button></div></section>;
}

function Cart() {
  const [items, setItems] = useState(cartItems());
  const total = useMemo(() => items.reduce((s, i) => s + i.monthlyPrice * i.quantity * i.durationMonths, 0), [items]);
  const remove = index => { const next = items.filter((_, i) => i !== index); setItems(next); saveCart(next); };
  return <section><h1>Panier</h1>{items.map((i, index) => <div className="row" key={index}><span>{i.name}</span><span>{i.durationMonths} mois</span><strong>{(i.monthlyPrice * i.durationMonths).toFixed(2)} €</strong><button onClick={() => remove(index)}>Supprimer</button></div>)}<h2>Total estimé : {total.toFixed(2)} €</h2><Link className="primary" to="/checkout">Commander</Link></section>;
}

function Checkout() {
  const [done, setDone] = useState(null);
  const submit = async () => {
    for (const item of cartItems()) await api('/cart/items', { method: 'POST', body: JSON.stringify(item) });
    const order = await api('/checkout', { method: 'POST' });
    saveCart([]);
    setDone(order);
  };
  return <section><h1>Checkout</h1><p>Le paiement est mocké côté serveur. Aucun numéro de carte n'est demandé.</p>{done ? <p>Commande #{done.orderId} confirmée.</p> : <button className="primary" onClick={submit}>Valider la commande</button>}</section>;
}

function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  return <AuthForm title="Connexion" submit={async payload => { await login(payload.email, payload.password); navigate('/compte'); }}/>;
}
function Register() {
  const { register } = useAuth();
  const navigate = useNavigate();
  return <AuthForm title="Créer un compte" register submit={async payload => { await register(payload); navigate('/compte'); }}/>;
}
function AuthForm({ title, submit, register }) {
  const [form, setForm] = useState({ email: '', password: '', firstName: '', lastName: '' });
  const [error, setError] = useState('');
  return <form className="panel" onSubmit={async e => { e.preventDefault(); setError(''); try { await submit(form); } catch (err) { setError(err.message); } }}><h1>{title}</h1>{register && <><input placeholder="Prénom" onChange={e => setForm({ ...form, firstName: e.target.value })}/><input placeholder="Nom" onChange={e => setForm({ ...form, lastName: e.target.value })}/></>}<input placeholder="Email" type="email" onChange={e => setForm({ ...form, email: e.target.value })}/><input placeholder="Mot de passe" type="password" onChange={e => setForm({ ...form, password: e.target.value })}/>{error && <p className="error">{error}</p>}<button className="primary">Continuer</button><Link to="/mot-de-passe-oublie">Mot de passe oublié</Link></form>;
}

function Forgot() { return <section><h1>Mot de passe oublié</h1><p>Flux prêt côté interface. L'envoi d'e-mail reste à brancher côté backend.</p></section>; }
function Account() { const { user } = useAuth(); return <section><h1>Mon compte</h1><p>{user.email}</p><Link to="/commandes">Mes commandes</Link></section>; }
function Orders() { const [orders, setOrders] = useState([]); useEffect(() => { api('/me/orders').then(d => setOrders(d.items)); }, []); return <section><h1>Mes commandes</h1>{orders.map(o => <Link className="row" to={`/commandes/${o.id}`} key={o.id}>Commande #{o.id} - {o.total} €</Link>)}</section>; }
function OrderDetail() { const { id } = useParams(); const [order, setOrder] = useState(null); useEffect(() => { api(`/me/orders/${id}`).then(setOrder); }, [id]); return <section><h1>Commande #{id}</h1>{order?.items?.map(i => <div className="row" key={i.id}>{i.product_name}<strong>{i.line_total} €</strong></div>)}</section>; }
function Contact() { const [sent, setSent] = useState(false); const [form, setForm] = useState({ email: '', subject: '', message: '' }); return <form className="panel" onSubmit={async e => { e.preventDefault(); await api('/contact', { method: 'POST', body: JSON.stringify(form) }); setSent(true); }}><h1>Contact support</h1><input placeholder="Email" onChange={e => setForm({ ...form, email: e.target.value })}/><input placeholder="Sujet" onChange={e => setForm({ ...form, subject: e.target.value })}/><textarea placeholder="Message" onChange={e => setForm({ ...form, message: e.target.value })}/><button className="primary">Envoyer</button>{sent && <p>Message envoyé.</p>}</form>; }

createRoot(document.getElementById('root')).render(<Router><AuthProvider><Layout/></AuthProvider></Router>);
