import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Link, Navigate, Route, BrowserRouter as Router, Routes, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { Shield, ShoppingCart, User, Search, LogOut, Instagram } from 'lucide-react';
import './styles.css';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api';
const AuthContext = createContext(null);

// Filet de sécurité : sans ça, une erreur de rendu inattendue sur une page
// laisse un écran totalement blanc et silencieux (comportement par défaut de React),
// récupérable uniquement par un rechargement complet. On affiche un message à la place.
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }
  static getDerivedStateFromError() {
    return { hasError: true };
  }
  componentDidCatch(error, info) {
    console.error('Erreur de rendu interceptée :', error, info);
  }
  render() {
    if (this.state.hasError) {
      return (
        <section className="panel">
          <h1>Un problème est survenu</h1>
          <p>La page n'a pas pu s'afficher correctement.</p>
          <button className="primary" onClick={() => window.location.reload()}>Recharger la page</button>
        </section>
      );
    }
    return this.props.children;
  }
}

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
  // Jeton expiré ou invalide sur une route protégée : on purge la session locale
  // et on renvoie à la connexion, au lieu de laisser les pages échouer en silence.
  if (res.status === 401 && token && !path.startsWith('/auth/')) {
    localStorage.removeItem('cyna_token');
    localStorage.removeItem('cyna_user');
    window.location.href = '/login';
    throw new Error('Session expirée, reconnectez-vous.');
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(data.message || data.error || 'Erreur API');
    err.code = data.error || null;
    err.fieldErrors = data.errors || null;
    throw err;
  }
  return data;
}

function AuthProvider({ children }) {
  const [user, setUser] = useState(JSON.parse(localStorage.getItem('cyna_user') || 'null'));
  // Étape 1 : email + mot de passe. Ne connecte pas : déclenche l'envoi du code 2FA par e-mail.
  const login = async (email, password) => {
    return api('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) });
  };
  // Étape 2 : le code à 6 chiffres reçu par e-mail. C'est ici que le jeton est délivré.
  const verify2fa = async (email, code) => {
    const data = await api('/auth/verify-2fa', { method: 'POST', body: JSON.stringify({ email, code }) });
    localStorage.setItem('cyna_token', data.token);
    localStorage.setItem('cyna_user', JSON.stringify(data.user));
    setUser(data.user);
  };
  const register = async (payload) => {
    // Ne connecte plus automatiquement : le compte doit d'abord être confirmé par e-mail.
    return api('/auth/register', { method: 'POST', body: JSON.stringify(payload) });
  };
  // Adopte une session déjà émise par le serveur (ex : connexion auto après
  // confirmation de l'adresse e-mail — le lien à usage unique vaut preuve).
  const adopt = (data) => {
    if (!data?.token) return;
    localStorage.setItem('cyna_token', data.token);
    localStorage.setItem('cyna_user', JSON.stringify(data.user));
    setUser(data.user);
  };
  const logout = () => {
    localStorage.removeItem('cyna_token');
    localStorage.removeItem('cyna_user');
    setUser(null);
  };
  return <AuthContext.Provider value={{ user, login, verify2fa, register, adopt, logout }}>{children}</AuthContext.Provider>;
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
  return <><header><Link className="brand" to="/"><Shield/> CYNA</Link><nav><Link to="/catalogue">Catalogue</Link><Link to="/contact">Contact</Link><Link to="/panier"><ShoppingCart/> {count}</Link>{user ? <><Link to="/compte"><User/> {user.firstName || 'Compte'}</Link><button onClick={logout}><LogOut size={16}/> Quitter</button></> : <Link to="/login">Connexion</Link>}</nav></header><main><Routes><Route path="/" element={<Home/>}/><Route path="/catalogue" element={<Catalogue/>}/><Route path="/categorie/:id" element={<Category/>}/><Route path="/recherche" element={<SearchPage/>}/><Route path="/produits/:id" element={<ProductDetail/>}/><Route path="/panier" element={<Cart/>}/><Route path="/checkout" element={<Checkout/>}/><Route path="/login" element={<Login/>}/><Route path="/register" element={<Register/>}/><Route path="/verifier-email" element={<VerifyEmail/>}/><Route path="/confirmer-email" element={<ConfirmEmailChange/>}/><Route path="/mot-de-passe-oublie" element={<Forgot/>}/><Route path="/compte" element={<Protected><Account/></Protected>}/><Route path="/commandes" element={<Protected><Orders/></Protected>}/><Route path="/commandes/:id" element={<Protected><OrderDetail/></Protected>}/><Route path="/commandes/:id/facture" element={<Protected><InvoiceView/></Protected>}/><Route path="/contact" element={<Contact/>}/><Route path="/mentions-legales" element={<MentionsLegales/>}/><Route path="/cgu" element={<Cgu/>}/></Routes></main><Footer/></>;
}

function Protected({ children }) {
  return useAuth().user ? children : <Navigate to="/login"/>;
}

// Pied de page présent sur toutes les pages (rendu dans Layout, hors <Routes>).
function Footer() {
  return (
    <footer className="site-footer">
      <div className="footer-brand">
        <span className="brand"><Shield/> CYNA</span>
        <p className="muted">Services SaaS de cybersécurité — SOC, EDR, XDR.</p>
      </div>
      <nav className="footer-links">
        <Link to="/mentions-legales">Mentions légales</Link>
        <Link to="/cgu">CGU</Link>
        <Link to="/contact">Contact</Link>
        <a href="https://www.instagram.com/h3hitema/" target="_blank" rel="noreferrer" aria-label="Instagram">
          <Instagram size={17}/> Instagram
        </a>
      </nav>
      <p className="muted">© {new Date().getFullYear()} CYNA — Projet fil rouge</p>
    </footer>
  );
}

function MentionsLegales() {
  return (
    <section className="legal">
      <h1>Mentions légales</h1>

      <h2>Éditeur du site</h2>
      <p>
        Le site CYNA est édité dans le cadre d'un projet d'étude (« projet fil rouge ») réalisé par des étudiants.
        CYNA est une société fictive de services SaaS de cybersécurité (SOC, EDR, XDR) : aucune offre commerciale
        réelle n'est proposée et aucun paiement réel n'est effectué sur ce site.
      </p>

      <h2>Directeur de publication</h2>
      <p>L'équipe projet CYNA (étudiants), dans le cadre de leur formation.</p>

      <h2>Hébergement</h2>
      <p>
        Le site est hébergé dans un environnement de démonstration (conteneurs Docker) à des fins pédagogiques.
        Il n'est pas exploité en production.
      </p>

      <h2>Propriété intellectuelle</h2>
      <p>
        L'ensemble des contenus du site (textes, logos, maquettes, code) est produit à des fins pédagogiques.
        Les illustrations proviennent de banques d'images libres d'utilisation (Unsplash).
      </p>

      <h2>Données personnelles (RGPD)</h2>
      <p>
        Les données collectées (nom, prénom, adresse e-mail, adresse de facturation) servent uniquement au
        fonctionnement du compte client et des commandes de démonstration. Les mots de passe sont stockés hachés,
        les numéros de carte ne sont jamais conservés (seuls le nom du porteur et les 4 derniers chiffres le sont).
        Conformément au RGPD, vous pouvez demander l'accès, la rectification ou la suppression de vos données via la
        page <Link to="/contact">Contact</Link>.
      </p>

      <h2>Cookies</h2>
      <p>
        Le site n'utilise pas de cookies de suivi ni de mesure d'audience. Seul le stockage local du navigateur
        est utilisé pour la session de connexion et le panier.
      </p>
    </section>
  );
}

function Cgu() {
  return (
    <section className="legal">
      <h1>Conditions générales d'utilisation</h1>

      <h2>1. Objet</h2>
      <p>
        Les présentes CGU encadrent l'utilisation de la plateforme CYNA, site de démonstration permettant de
        parcourir un catalogue de services de cybersécurité par abonnement (SOC, EDR, XDR), de constituer un panier
        et de simuler une commande.
      </p>

      <h2>2. Accès au service</h2>
      <p>
        La consultation du catalogue est libre. La commande nécessite la création d'un compte, confirmée par e-mail.
        La connexion est protégée par une double authentification (code à 6 chiffres envoyé par e-mail).
      </p>

      <h2>3. Compte utilisateur</h2>
      <p>
        L'utilisateur est responsable de la confidentialité de ses identifiants. Le mot de passe doit respecter les
        règles de robustesse affichées à l'inscription. En cas d'oubli, une procédure de réinitialisation par code
        e-mail est disponible. L'adresse e-mail et le mot de passe sont modifiables depuis l'espace « Mon compte ».
      </p>

      <h2>4. Commandes et paiement</h2>
      <p>
        Les prix sont affichés en euros, par mois, pour des durées d'engagement de 1, 12 ou 24 mois. Le paiement est
        une <strong>simulation</strong> : aucune somme n'est débitée, aucune donnée bancaire complète n'est conservée.
        Une facture de démonstration est générée pour chaque commande.
      </p>

      <h2>5. Obligations de l'utilisateur</h2>
      <p>
        L'utilisateur s'engage à ne pas perturber le fonctionnement du site, à ne pas tenter d'accéder aux comptes
        d'autres utilisateurs ni aux fonctions d'administration, et à fournir des informations exactes.
      </p>

      <h2>6. Responsabilité</h2>
      <p>
        CYNA étant un projet pédagogique, le service est fourni « en l'état », sans garantie de disponibilité ni
        d'adéquation à un usage professionnel réel.
      </p>

      <h2>7. Droit applicable</h2>
      <p>
        Les présentes conditions sont soumises au droit français. Pour toute question :
        page <Link to="/contact">Contact</Link>.
      </p>
    </section>
  );
}

function Carousel({ slides }) {
  const [index, setIndex] = useState(0);
  useEffect(() => {
    if (slides.length < 2) return;
    const timer = setInterval(() => setIndex(i => (i + 1) % slides.length), 6000);
    return () => clearInterval(timer);
  }, [slides.length]);
  const slide = slides[index];
  return (
    <section className="carousel" style={{ backgroundImage: `linear-gradient(90deg, rgba(12,22,40,.82), rgba(12,22,40,.34)), url('${slide.image_url}')` }}>
      <div className="carousel-content">
        <p className="eyebrow">SOC - EDR - XDR</p>
        <h1>{slide.title}</h1>
        <p>{slide.subtitle}</p>
        <Link className="primary" to={slide.cta_url || '/catalogue'}>Voir les services</Link>
      </div>
      {slides.length > 1 && (
        <div className="carousel-dots">
          {slides.map((s, i) => (
            <button
              key={s.id}
              className={i === index ? 'dot active' : 'dot'}
              onClick={() => setIndex(i)}
              aria-label={`Aller au slide ${i + 1}`}
            />
          ))}
        </div>
      )}
    </section>
  );
}

function CategoryGrid({ categories }) {
  if (!categories.length) return null;
  return (
    <section className="category-grid">
      <h2>Nos catégories</h2>
      <div className="grid">
        {categories.map(c => (
          <Link key={c.id} to={`/categorie/${c.id}`} className="category-card">
            {c.image_url && <img className="category-img" src={c.image_url} alt={c.name}/>}
            <span className="eyebrow">{c.name}</span>
            <p>{c.description}</p>
          </Link>
        ))}
      </div>
    </section>
  );
}

// Blocs de texte de l'accueil, gérés dans le back-office (Textes accueil).
function HomeTextBlocks({ texts }) {
  if (!texts.length) return null;
  return (
    <section className="home-texts">
      <div className="grid">
        {texts.map(t => (
          <article className="category-card" key={t.id}>
            <span className="eyebrow">{t.title}</span>
            <p>{t.content}</p>
          </article>
        ))}
      </div>
    </section>
  );
}

function Home() {
  const [slides, setSlides] = useState([]);
  const [categories, setCategories] = useState([]);
  const [featured, setFeatured] = useState([]);
  const [texts, setTexts] = useState([]);
  useEffect(() => {
    api('/home-carousel').then(d => setSlides(d.items || [])).catch(() => setSlides([]));
    api('/categories').then(d => setCategories(d.items || [])).catch(() => setCategories([]));
    api('/featured-products').then(d => setFeatured(d.items || [])).catch(() => setFeatured([]));
    api('/home-texts').then(d => setTexts(d.items || [])).catch(() => setTexts([]));
  }, []);
  return (
    <>
      {slides.length > 0 ? (
        <Carousel slides={slides}/>
      ) : (
        <section className="hero"><div><p className="eyebrow">SOC - EDR - XDR</p><h1>CYNA Cybersecurity SaaS</h1><p>Des services cyber managés pour protéger les entreprises avec une plateforme claire, mesurable et prête pour l'abonnement.</p><Link className="primary" to="/catalogue">Voir les services</Link></div></section>
      )}
      <HomeTextBlocks texts={texts}/>
      <CategoryGrid categories={categories}/>
      {featured.length > 0 && (
        <section className="featured">
          <h2>Top produits du moment</h2>
          <ProductGrid products={featured}/>
        </section>
      )}
    </>
  );
}

function Catalogue() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [sort, setSort] = useState('newest');
  useEffect(() => { api(`/products?sort=${sort}`).then(d => setProducts(d.items)); }, [sort]);
  useEffect(() => { api('/categories').then(d => setCategories(d.items)); }, []);
  return <>
    <Toolbar categories={categories}/>
    <div className="sort-bar">
      <label>Trier par{' '}
        <select value={sort} onChange={e => setSort(e.target.value)}>
          <option value="newest">Nouveauté</option>
          <option value="price_asc">Prix croissant</option>
          <option value="price_desc">Prix décroissant</option>
          <option value="stock">Disponibilité</option>
          <option value="name">Nom (A-Z)</option>
        </select>
      </label>
    </div>
    <ProductGrid products={products}/>
  </>;
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
  const [filters, setFilters] = useState({ mode: 'contains', minPrice: '', maxPrice: '', inStock: false, sort: 'name' });
  const q = params.get('q') || '';

  useEffect(() => {
    const query = new URLSearchParams({ q, mode: filters.mode, sort: filters.sort });
    if (filters.minPrice !== '') query.set('minPrice', filters.minPrice);
    if (filters.maxPrice !== '') query.set('maxPrice', filters.maxPrice);
    if (filters.inStock) query.set('inStock', '1');
    api(`/search?${query.toString()}`).then(d => setProducts(d.items));
  }, [q, filters]);

  return (
    <>
      <section className="search-head">
        <h1>Recherche{q && <> : « {q} »</>}</h1>
        <div className="search-filters">
          <label>Correspondance{' '}
            <select value={filters.mode} onChange={e => setFilters({ ...filters, mode: e.target.value })}>
              <option value="contains">Contient</option>
              <option value="starts">Commence par</option>
              <option value="exact">Exacte</option>
            </select>
          </label>
          <label>Prix min <input type="number" min="0" placeholder="€" value={filters.minPrice} onChange={e => setFilters({ ...filters, minPrice: e.target.value })}/></label>
          <label>Prix max <input type="number" min="0" placeholder="€" value={filters.maxPrice} onChange={e => setFilters({ ...filters, maxPrice: e.target.value })}/></label>
          <label className="check"><input type="checkbox" checked={filters.inStock} onChange={e => setFilters({ ...filters, inStock: e.target.checked })}/> En stock uniquement</label>
          <label>Trier par{' '}
            <select value={filters.sort} onChange={e => setFilters({ ...filters, sort: e.target.value })}>
              <option value="name">Nom (A-Z)</option>
              <option value="price_asc">Prix croissant</option>
              <option value="price_desc">Prix décroissant</option>
              <option value="newest">Nouveauté</option>
            </select>
          </label>
        </div>
        <p className="muted">{products.length} résultat{products.length > 1 ? 's' : ''} — la recherche porte sur le nom, la description et les caractéristiques techniques.</p>
      </section>
      <ProductGrid products={products}/>
    </>
  );
}

function Toolbar({ categories }) {
  const [q, setQ] = useState('');
  const navigate = useNavigate();
  return <section className="toolbar"><form onSubmit={e => { e.preventDefault(); navigate(`/recherche?q=${encodeURIComponent(q)}`); }}><Search/><input value={q} onChange={e => setQ(e.target.value)} placeholder="Rechercher SOC, EDR, XDR..."/></form><div>{categories.map(c => <Link key={c.id} to={`/categorie/${c.id}`}>{c.name}</Link>)}</div></section>;
}

function StockBadge({ stock }) {
  if (stock === undefined || stock === null) return null;
  const s = Number(stock);
  return <span className={s > 0 ? 'badge in-stock' : 'badge out-of-stock'}>{s > 0 ? `En stock (${s})` : 'Indisponible'}</span>;
}

function ProductGrid({ products }) {
  return <section className="grid">{products.map(p => <article className="card" key={p.id}><img src={p.image_url || 'https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&w=900&q=80'} alt=""/><div><p className="eyebrow">{p.category_name}</p><h2>{p.name}</h2><p>{p.description}</p><StockBadge stock={p.stock}/><strong>{Number(p.monthly_price).toFixed(2)} €/mois</strong><Link className="primary" to={`/produits/${p.id}`}>Détail</Link></div></article>)}</section>;
}

function ProductIllustrationsCarousel({ images }) {
  const [index, setIndex] = useState(0);
  useEffect(() => {
    setIndex(0);
    if (images.length < 2) return;
    const timer = setInterval(() => setIndex(i => (i + 1) % images.length), 5000);
    return () => clearInterval(timer);
  }, [images]);

  if (!images.length) {
    return <img src="https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&w=900&q=80" alt=""/>;
  }

  return (
    <div className="product-carousel">
      <img src={images[index].url} alt={images[index].alt || ''}/>
      {images.length > 1 && (
        <div className="carousel-dots product-carousel-dots">
          {images.map((img, i) => (
            <button
              key={img.id}
              className={i === index ? 'dot active' : 'dot'}
              onClick={() => setIndex(i)}
              aria-label={`Voir l'illustration ${i + 1}`}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function ProductDetail() {
  const { id } = useParams();
  const [p, setP] = useState(null);
  const [duration, setDuration] = useState(12);
  const [added, setAdded] = useState(false);
  useEffect(() => { setAdded(false); api(`/products/${id}`).then(setP); }, [id]);
  if (!p) return <p>Chargement...</p>;
  const available = Number(p.stock ?? 1) > 0;
  const add = () => { const items = cartItems(); items.push({ productId: p.id, name: p.name, monthlyPrice: Number(p.monthly_price), quantity: 1, durationMonths: duration }); saveCart(items); setAdded(true); };
  return (
    <>
      <section className="detail">
        <ProductIllustrationsCarousel images={p.images || []}/>
        <div>
          <p className="eyebrow">{p.category_name}</p>
          <h1>{p.name}</h1>
          <p>{p.description}</p>
          <StockBadge stock={p.stock}/>
          {p.technical_specs && (
            <>
              <h2 className="specs-title">Caractéristiques techniques</h2>
              <ul className="specs">
                {p.technical_specs.split('·').map(s => s.trim()).filter(Boolean).map(s => <li key={s}>{s}</li>)}
              </ul>
            </>
          )}
          <label>Durée<select value={duration} onChange={e => setDuration(Number(e.target.value))}><option value="1">1 mois</option><option value="12">12 mois</option><option value="24">24 mois</option></select></label>
          <strong>{(Number(p.monthly_price) * duration).toFixed(2)} €</strong>
          {available ? (
            <div className="cta-row">
              <button className="primary" onClick={add}>Ajouter au panier</button>
              <Link className="secondary" to={`/contact?sujet=${encodeURIComponent(`Demande d'essai gratuit - ${p.name}`)}`}>Demander un essai</Link>
            </div>
          ) : (
            <div className="cta-row">
              <button className="primary" disabled>Indisponible</button>
              <Link className="secondary" to={`/contact?sujet=${encodeURIComponent(`Me prévenir du retour en stock - ${p.name}`)}`}>Être prévenu du retour</Link>
            </div>
          )}
          {added && <p className="added">Ajouté au panier ✓ <Link to="/panier">Voir le panier</Link></p>}
        </div>
      </section>
      {p.similar?.length > 0 && (
        <section className="featured">
          <h2>Services similaires</h2>
          <ProductGrid products={p.similar}/>
        </section>
      )}
    </>
  );
}

function Cart() {
  const [items, setItems] = useState(cartItems());
  const total = useMemo(() => items.reduce((s, i) => s + i.monthlyPrice * i.quantity * i.durationMonths, 0), [items]);
  const remove = index => { const next = items.filter((_, i) => i !== index); setItems(next); saveCart(next); };
  return <section><h1>Panier</h1>{items.map((i, index) => <div className="row" key={index}><span>{i.name}</span><span>{i.durationMonths} mois</span><strong>{(i.monthlyPrice * i.durationMonths).toFixed(2)} €</strong><button onClick={() => remove(index)}>Supprimer</button></div>)}<h2>Total estimé : {total.toFixed(2)} €</h2><Link className="primary" to="/checkout">Commander</Link></section>;
}

function formatCardNumber(value) {
  const digits = value.replace(/\D/g, '').slice(0, 16);
  return digits.replace(/(.{4})/g, '$1 ').trim();
}

function formatCardExpiry(value) {
  const digits = value.replace(/\D/g, '').slice(0, 4);
  return digits.length > 2 ? `${digits.slice(0, 2)}/${digits.slice(2)}` : digits;
}

function Checkout() {
  const { user } = useAuth();
  const [authMode, setAuthMode] = useState('login'); // invité : se connecter ou créer un compte
  const [done, setDone] = useState(null);
  const [address, setAddress] = useState({ company: '', firstName: '', lastName: '', line1: '', line2: '', city: '', region: '', postalCode: '', phone: '', country: 'France' });
  const [payment, setPayment] = useState({ cardName: '', cardNumber: '', cardExpiry: '', cvv: '' });
  const [errors, setErrors] = useState({});
  const [globalError, setGlobalError] = useState('');

  useEffect(() => {
    if (!user) return;
    api('/me/address').then(d => { if (d.address) setAddress({
      company: d.address.company || '',
      firstName: d.address.first_name || user.firstName || '',
      lastName: d.address.last_name || user.lastName || '',
      line1: d.address.line1 || '',
      line2: d.address.line2 || '',
      city: d.address.city || '',
      region: d.address.region || '',
      postalCode: d.address.postal_code || '',
      phone: d.address.phone || '',
      country: d.address.country || 'France',
    }); }).catch(() => {});
  }, [user]);

  // Parcours invité : possibilité de se connecter OU de créer un compte sans quitter le checkout.
  if (!user) {
    return (
      <section>
        <h1>Finaliser la commande</h1>
        <p style={{ padding: '0 0 8px' }}>Connectez-vous ou créez un compte pour valider votre panier (il est conservé).</p>
        <div className="auth-toggle">
          <button className={authMode === 'login' ? 'primary' : ''} onClick={() => setAuthMode('login')}>J'ai déjà un compte</button>
          <button className={authMode === 'register' ? 'primary' : ''} onClick={() => setAuthMode('register')}>Créer un compte</button>
        </div>
        {authMode === 'login' ? <Login redirectTo="/checkout"/> : <Register/>}
      </section>
    );
  }

  const submit = async () => {
    setGlobalError('');
    const nextErrors = {};
    if (!address.firstName.trim()) nextErrors.firstName = 'Le prénom est requis.';
    if (!address.lastName.trim()) nextErrors.lastName = 'Le nom est requis.';
    if (!address.line1.trim()) nextErrors.line1 = "L'adresse est requise.";
    if (!address.city.trim()) nextErrors.city = 'La ville est requise.';
    if (!address.postalCode.trim()) nextErrors.postalCode = 'Le code postal est requis.';
    if (!payment.cardName.trim()) nextErrors.cardName = 'Le nom du porteur est requis.';
    if (payment.cardNumber.replace(/\D/g, '').length !== 16) nextErrors.cardNumber = 'Le numéro de carte doit contenir 16 chiffres.';
    if (!/^(0[1-9]|1[0-2])\/[0-9]{2}$/.test(payment.cardExpiry)) nextErrors.cardExpiry = 'Format attendu : MM/AA.';
    if (!/^[0-9]{3}$/.test(payment.cvv)) nextErrors.cvv = 'Le CVV doit contenir 3 chiffres.';
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length) return;
    try {
      for (const item of cartItems()) await api('/cart/items', { method: 'POST', body: JSON.stringify(item) });
      const order = await api('/checkout', { method: 'POST', body: JSON.stringify({ address, payment }) });
      saveCart([]);
      setDone(order);
    } catch (err) {
      if (err.fieldErrors) setErrors(err.fieldErrors);
      else setGlobalError(err.message);
    }
  };

  if (done) {
    return (
      <section>
        <h1>Merci pour votre commande</h1>
        <p>Commande #{done.orderId} confirmée.</p>
        <p>Payé avec la carte de {done.payment.cardName} se terminant par •••• {done.payment.last4}.</p>
        <Link className="primary" to={`/commandes/${done.orderId}/facture`}>Voir la facture</Link>
      </section>
    );
  }

  return (
    <section className="panel">
      <h1>Adresse de facturation</h1>
      <div className="card-row">
        <input placeholder="Prénom" value={address.firstName} onChange={e => setAddress({ ...address, firstName: e.target.value })}/>
        <input placeholder="Nom" value={address.lastName} onChange={e => setAddress({ ...address, lastName: e.target.value })}/>
      </div>
      {errors.firstName && <p className="error">{errors.firstName}</p>}
      {errors.lastName && <p className="error">{errors.lastName}</p>}
      <input placeholder="Société (optionnel)" value={address.company} onChange={e => setAddress({ ...address, company: e.target.value })}/>
      <input placeholder="Adresse" value={address.line1} onChange={e => setAddress({ ...address, line1: e.target.value })}/>
      {errors.line1 && <p className="error">{errors.line1}</p>}
      <input placeholder="Complément d'adresse (optionnel)" value={address.line2} onChange={e => setAddress({ ...address, line2: e.target.value })}/>
      <div className="card-row">
        <input placeholder="Code postal" value={address.postalCode} onChange={e => setAddress({ ...address, postalCode: e.target.value })}/>
        <input placeholder="Ville" value={address.city} onChange={e => setAddress({ ...address, city: e.target.value })}/>
      </div>
      {errors.postalCode && <p className="error">{errors.postalCode}</p>}
      {errors.city && <p className="error">{errors.city}</p>}
      <div className="card-row">
        <input placeholder="Région (optionnel)" value={address.region} onChange={e => setAddress({ ...address, region: e.target.value })}/>
        <input placeholder="Pays" value={address.country} onChange={e => setAddress({ ...address, country: e.target.value })}/>
      </div>
      <input placeholder="Téléphone (optionnel)" inputMode="tel" value={address.phone} onChange={e => setAddress({ ...address, phone: e.target.value })}/>

      <h1>Paiement</h1>
      <p>Simulation de paiement : aucune carte réelle n'est débitée, aucune information bancaire n'est transmise à un tiers.</p>
      <input placeholder="Nom sur la carte" value={payment.cardName} onChange={e => setPayment({ ...payment, cardName: e.target.value })}/>
      {errors.cardName && <p className="error">{errors.cardName}</p>}
      <input placeholder="Numéro de carte" inputMode="numeric" value={payment.cardNumber} onChange={e => setPayment({ ...payment, cardNumber: formatCardNumber(e.target.value) })}/>
      {errors.cardNumber && <p className="error">{errors.cardNumber}</p>}
      <div className="card-row">
        <input placeholder="MM/AA" inputMode="numeric" value={payment.cardExpiry} onChange={e => setPayment({ ...payment, cardExpiry: formatCardExpiry(e.target.value) })}/>
        <input placeholder="CVV" inputMode="numeric" value={payment.cvv} onChange={e => setPayment({ ...payment, cvv: e.target.value.replace(/\D/g, '').slice(0, 3) })}/>
      </div>
      {errors.cardExpiry && <p className="error">{errors.cardExpiry}</p>}
      {errors.cvv && <p className="error">{errors.cvv}</p>}
      {globalError && <p className="error">{globalError}</p>}
      <button className="primary" onClick={submit}>Valider la commande</button>
    </section>
  );
}

// Règles de mot de passe identiques à celles vérifiées côté serveur (ApiController::validatePassword).
function passwordRules(password) {
  return [
    { label: 'Au moins 8 caractères', ok: password.length >= 8 },
    { label: 'Une majuscule', ok: /[A-Z]/.test(password) },
    { label: 'Une minuscule', ok: /[a-z]/.test(password) },
    { label: 'Un chiffre', ok: /[0-9]/.test(password) },
    { label: 'Un caractère spécial', ok: /[^A-Za-z0-9]/.test(password) },
  ];
}

function Login({ redirectTo = '/compte' }) {
  const { login, verify2fa } = useAuth();
  const navigate = useNavigate();
  const [notVerifiedEmail, setNotVerifiedEmail] = useState('');
  const [resendStatus, setResendStatus] = useState('');
  // Étape 2FA : identifiants gardés en mémoire (jamais persistés) le temps de saisir le code,
  // pour permettre le bouton "Renvoyer un code" qui rejoue simplement /auth/login.
  const [pending2fa, setPending2fa] = useState(null);
  const [code, setCode] = useState('');
  const [codeError, setCodeError] = useState('');
  const [codeInfo, setCodeInfo] = useState('');

  const resend = async () => {
    setResendStatus('Envoi en cours...');
    try {
      const data = await api('/auth/resend-verification', { method: 'POST', body: JSON.stringify({ email: notVerifiedEmail }) });
      setResendStatus(data.message);
    } catch {
      setResendStatus("L'envoi a échoué, réessayez dans un instant.");
    }
  };

  const submitCode = async e => {
    e.preventDefault();
    setCodeError('');
    try {
      await verify2fa(pending2fa.email, code);
      navigate(redirectTo);
    } catch (err) {
      setCodeError(err.message);
    }
  };

  const resendCode = async () => {
    setCodeInfo('Envoi en cours...');
    setCodeError('');
    try {
      const data = await login(pending2fa.email, pending2fa.password);
      setCodeInfo(data.message);
    } catch {
      setCodeInfo('');
      setCodeError("L'envoi a échoué, réessayez dans un instant.");
    }
  };

  if (pending2fa) {
    return (
      <form className="panel" onSubmit={submitCode}>
        <h1>Vérification en deux étapes</h1>
        <p>Un code à 6 chiffres a été envoyé à <strong>{pending2fa.email}</strong>. Il expire dans 10 minutes.</p>
        <input
          placeholder="Code à 6 chiffres"
          inputMode="numeric"
          autoFocus
          value={code}
          onChange={e => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
        />
        {codeError && <p className="error">{codeError}</p>}
        {codeInfo && <p>{codeInfo}</p>}
        <button className="primary" disabled={code.length !== 6}>Se connecter</button>
        <button type="button" onClick={resendCode}>Renvoyer un code</button>
        <button type="button" onClick={() => { setPending2fa(null); setCode(''); setCodeError(''); setCodeInfo(''); }}>Retour</button>
      </form>
    );
  }

  return (
    <>
      <AuthForm
        title="Connexion"
        submit={async payload => {
          setNotVerifiedEmail('');
          try {
            const data = await login(payload.email, payload.password);
            if (data.status === '2fa_required') setPending2fa({ email: payload.email, password: payload.password });
          } catch (err) {
            if (err.code === 'not_verified') setNotVerifiedEmail(payload.email);
            throw err;
          }
        }}
      />
      {notVerifiedEmail && (
        <section className="panel" style={{ marginTop: -12 }}>
          <p>Vous n'avez pas encore confirmé cette adresse.</p>
          <button className="primary" onClick={resend}>Renvoyer l'e-mail de confirmation</button>
          {resendStatus && <p>{resendStatus}</p>}
        </section>
      )}
    </>
  );
}

function Register() {
  const { register } = useAuth();
  const [done, setDone] = useState(null);

  if (done) {
    return (
      <section className="panel">
        <h1>Vérifiez votre boîte mail</h1>
        <p>{done.message}</p>
        <p>Si aucun message n'arrive, pensez à vérifier le dossier spam. (En local sans SMTP configuré, les e-mails sont capturés par <a href="http://localhost:8025" target="_blank" rel="noreferrer">Mailpit</a>.)</p>
        <Link className="primary" to="/login">Aller à la connexion</Link>
      </section>
    );
  }

  return <AuthForm title="Créer un compte" register submit={async payload => setDone(await register(payload))}/>;
}

function AuthForm({ title, submit, register }) {
  const [form, setForm] = useState({ email: '', password: '', firstName: '', lastName: '' });
  const [fieldErrors, setFieldErrors] = useState({});
  const [globalError, setGlobalError] = useState('');
  const rules = register ? passwordRules(form.password) : [];

  const onSubmit = async e => {
    e.preventDefault();
    setGlobalError('');
    setFieldErrors({});
    if (register && rules.some(r => !r.ok)) {
      setFieldErrors({ password: 'Le mot de passe ne respecte pas encore toutes les règles ci-dessous.' });
      return;
    }
    try {
      await submit(form);
    } catch (err) {
      if (err.fieldErrors) setFieldErrors(err.fieldErrors);
      else setGlobalError(err.message);
    }
  };

  return (
    <form className="panel" onSubmit={onSubmit}>
      <h1>{title}</h1>
      {register && (
        <>
          <input placeholder="Prénom" value={form.firstName} onChange={e => setForm({ ...form, firstName: e.target.value })}/>
          {fieldErrors.firstName && <p className="error">{fieldErrors.firstName}</p>}
          <input placeholder="Nom" value={form.lastName} onChange={e => setForm({ ...form, lastName: e.target.value })}/>
          {fieldErrors.lastName && <p className="error">{fieldErrors.lastName}</p>}
        </>
      )}
      <input placeholder="Email" type="email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })}/>
      {fieldErrors.email && <p className="error">{fieldErrors.email}</p>}
      <input placeholder="Mot de passe" type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })}/>
      {register && (
        <ul className="password-rules">
          {rules.map(r => <li key={r.label} className={r.ok ? 'ok' : ''}>{r.label}</li>)}
        </ul>
      )}
      {fieldErrors.password && <p className="error">{fieldErrors.password}</p>}
      {globalError && <p className="error">{globalError}</p>}
      <button className="primary">Continuer</button>
      {register ? (
        <Link to="/login">Déjà un compte ? Se connecter</Link>
      ) : (
        <>
          <Link to="/register">Pas encore de compte ? Créer un compte</Link>
          <Link to="/mot-de-passe-oublie">Mot de passe oublié</Link>
        </>
      )}
    </form>
  );
}

function VerifyEmail() {
  const [params] = useSearchParams();
  const { adopt } = useAuth();
  const [state, setState] = useState({ loading: true, message: '', ok: false });

  useEffect(() => {
    const token = params.get('token') || '';
    api(`/auth/verify?token=${encodeURIComponent(token)}`)
      .then(data => {
        adopt(data); // connexion automatique : le lien e-mail à usage unique vaut preuve
        setState({ loading: false, message: data.message, ok: true });
      })
      .catch(err => setState({ loading: false, message: err.message, ok: false }));
  }, [params]);

  if (state.loading) return <section><h1>Vérification en cours...</h1></section>;
  return (
    <section className="panel">
      <h1>{state.ok ? 'Compte confirmé' : 'Lien invalide'}</h1>
      <p>{state.message}</p>
      {state.ok && <Link className="primary" to="/compte">Accéder à mon compte</Link>}
    </section>
  );
}

function ConfirmEmailChange() {
  const [params] = useSearchParams();
  const { logout } = useAuth();
  const [state, setState] = useState({ loading: true, message: '', ok: false });

  useEffect(() => {
    const token = params.get('token') || '';
    api(`/auth/confirm-email?token=${encodeURIComponent(token)}`)
      .then(data => {
        setState({ loading: false, message: data.message, ok: true });
        // Le jeton en cours porte l'ancienne adresse : on déconnecte proprement.
        logout();
      })
      .catch(err => setState({ loading: false, message: err.message, ok: false }));
  }, [params]);

  if (state.loading) return <section><h1>Confirmation en cours...</h1></section>;
  return (
    <section className="panel">
      <h1>{state.ok ? 'Adresse e-mail modifiée' : 'Lien invalide'}</h1>
      <p>{state.message}</p>
      <Link className="primary" to="/login">Se connecter</Link>
    </section>
  );
}

function Forgot() {
  const [step, setStep] = useState('email'); // 'email' → 'reset' → 'done'
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [errors, setErrors] = useState({});
  const [info, setInfo] = useState('');
  const rules = passwordRules(newPassword);

  const requestCode = async e => {
    e.preventDefault();
    setErrors({});
    try {
      const data = await api('/auth/forgot-password', { method: 'POST', body: JSON.stringify({ email }) });
      setInfo(data.message);
      setStep('reset');
    } catch (err) {
      setErrors({ global: err.message });
    }
  };

  const resetPassword = async e => {
    e.preventDefault();
    setErrors({});
    if (rules.some(r => !r.ok)) {
      setErrors({ newPassword: 'Le nouveau mot de passe ne respecte pas encore toutes les règles ci-dessous.' });
      return;
    }
    try {
      const data = await api('/auth/reset-password', { method: 'POST', body: JSON.stringify({ email, code, newPassword }) });
      setInfo(data.message);
      setStep('done');
    } catch (err) {
      if (err.fieldErrors) setErrors(err.fieldErrors);
      else setErrors({ global: err.message });
    }
  };

  if (step === 'done') {
    return (
      <section className="panel">
        <h1>Mot de passe réinitialisé</h1>
        <p>{info}</p>
        <Link className="primary" to="/login">Se connecter</Link>
      </section>
    );
  }

  if (step === 'reset') {
    return (
      <form className="panel" onSubmit={resetPassword}>
        <h1>Réinitialiser le mot de passe</h1>
        <p>{info}</p>
        <input
          placeholder="Code à 6 chiffres reçu par e-mail"
          inputMode="numeric"
          autoFocus
          value={code}
          onChange={e => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
        />
        <input placeholder="Nouveau mot de passe" type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)}/>
        <ul className="password-rules">
          {rules.map(r => <li key={r.label} className={r.ok ? 'ok' : ''}>{r.label}</li>)}
        </ul>
        {errors.newPassword && <p className="error">{errors.newPassword}</p>}
        {errors.global && <p className="error">{errors.global}</p>}
        <button className="primary" disabled={code.length !== 6}>Réinitialiser</button>
        <button type="button" onClick={requestCode}>Renvoyer un code</button>
      </form>
    );
  }

  return (
    <form className="panel" onSubmit={requestCode}>
      <h1>Mot de passe oublié</h1>
      <p>Saisissez l'adresse e-mail de votre compte : un code de réinitialisation vous sera envoyé.</p>
      <input placeholder="Email" type="email" autoFocus value={email} onChange={e => setEmail(e.target.value)}/>
      {errors.global && <p className="error">{errors.global}</p>}
      <button className="primary">Envoyer le code</button>
      <Link to="/login">Retour à la connexion</Link>
    </form>
  );
}
function subscriptionStatusLabel(sub) {
  const active = sub.status === 'active' && new Date(sub.ends_at) > new Date();
  return active ? 'Actif' : 'Expiré';
}

function ChangeEmailForm() {
  const [form, setForm] = useState({ newEmail: '', password: '' });
  const [errors, setErrors] = useState({});
  const [message, setMessage] = useState('');

  const submit = async e => {
    e.preventDefault();
    setErrors({});
    setMessage('');
    try {
      const data = await api('/me/email', { method: 'POST', body: JSON.stringify(form) });
      setMessage(data.message);
      setForm({ newEmail: '', password: '' });
    } catch (err) {
      if (err.fieldErrors) setErrors(err.fieldErrors);
      else setErrors({ global: err.message });
    }
  };

  return (
    <form className="panel" onSubmit={submit}>
      <h2>Changer d'adresse e-mail</h2>
      <p>Un lien de confirmation sera envoyé à la nouvelle adresse. Le changement ne prend effet qu'après ce clic.</p>
      <input placeholder="Nouvelle adresse e-mail" type="email" value={form.newEmail} onChange={e => setForm({ ...form, newEmail: e.target.value })}/>
      {errors.newEmail && <p className="error">{errors.newEmail}</p>}
      <input placeholder="Mot de passe actuel" type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })}/>
      {errors.password && <p className="error">{errors.password}</p>}
      {errors.global && <p className="error">{errors.global}</p>}
      {message && <p>{message}</p>}
      <button className="primary">Envoyer le lien de confirmation</button>
    </form>
  );
}

function ChangePasswordForm() {
  const [form, setForm] = useState({ currentPassword: '', newPassword: '' });
  const [errors, setErrors] = useState({});
  const [message, setMessage] = useState('');
  const rules = passwordRules(form.newPassword);

  const submit = async e => {
    e.preventDefault();
    setErrors({});
    setMessage('');
    if (rules.some(r => !r.ok)) {
      setErrors({ newPassword: 'Le nouveau mot de passe ne respecte pas encore toutes les règles ci-dessous.' });
      return;
    }
    try {
      const data = await api('/me/password', { method: 'POST', body: JSON.stringify(form) });
      setMessage(data.message);
      setForm({ currentPassword: '', newPassword: '' });
    } catch (err) {
      if (err.fieldErrors) setErrors(err.fieldErrors);
      else setErrors({ global: err.message });
    }
  };

  return (
    <form className="panel" onSubmit={submit}>
      <h2>Changer de mot de passe</h2>
      <input placeholder="Mot de passe actuel" type="password" value={form.currentPassword} onChange={e => setForm({ ...form, currentPassword: e.target.value })}/>
      {errors.currentPassword && <p className="error">{errors.currentPassword}</p>}
      <input placeholder="Nouveau mot de passe" type="password" value={form.newPassword} onChange={e => setForm({ ...form, newPassword: e.target.value })}/>
      <ul className="password-rules">
        {rules.map(r => <li key={r.label} className={r.ok ? 'ok' : ''}>{r.label}</li>)}
      </ul>
      {errors.newPassword && <p className="error">{errors.newPassword}</p>}
      {errors.global && <p className="error">{errors.global}</p>}
      {message && <p>{message}</p>}
      <button className="primary">Modifier le mot de passe</button>
    </form>
  );
}

// Infos personnelles éditables (prénom / nom) via PATCH /me.
function PersonalInfoForm() {
  const { user } = useAuth();
  const [form, setForm] = useState({ firstName: user?.firstName || '', lastName: user?.lastName || '' });
  const [message, setMessage] = useState('');
  const submit = async e => {
    e.preventDefault();
    const data = await api('/me', { method: 'PATCH', body: JSON.stringify(form) });
    localStorage.setItem('cyna_user', JSON.stringify(data.user));
    setMessage('Informations mises à jour.');
  };
  return (
    <form className="panel" onSubmit={submit}>
      <h2>Mes informations</h2>
      <p className="muted">{user?.email}</p>
      <div className="card-row">
        <input placeholder="Prénom" value={form.firstName} onChange={e => setForm({ ...form, firstName: e.target.value })}/>
        <input placeholder="Nom" value={form.lastName} onChange={e => setForm({ ...form, lastName: e.target.value })}/>
      </div>
      {message && <p>{message}</p>}
      <button className="primary">Enregistrer</button>
    </form>
  );
}

// Adresse de facturation gérée depuis le profil (PUT /me/address).
function AddressForm() {
  const [f, setF] = useState({ firstName: '', lastName: '', company: '', line1: '', line2: '', city: '', region: '', postalCode: '', phone: '', country: 'France' });
  const [message, setMessage] = useState('');
  const [errors, setErrors] = useState({});
  useEffect(() => {
    api('/me/address').then(d => { if (d.address) setF({
      firstName: d.address.first_name || '', lastName: d.address.last_name || '', company: d.address.company || '',
      line1: d.address.line1 || '', line2: d.address.line2 || '', city: d.address.city || '', region: d.address.region || '',
      postalCode: d.address.postal_code || '', phone: d.address.phone || '', country: d.address.country || 'France',
    }); }).catch(() => {});
  }, []);
  const submit = async e => {
    e.preventDefault();
    setErrors({});
    setMessage('');
    try {
      await api('/me/address', { method: 'PUT', body: JSON.stringify(f) });
      setMessage('Adresse enregistrée.');
    } catch (err) {
      if (err.fieldErrors) setErrors(err.fieldErrors);
      else setMessage(err.message);
    }
  };
  return (
    <form className="panel" onSubmit={submit}>
      <h2>Mon adresse de facturation</h2>
      <div className="card-row">
        <input placeholder="Prénom" value={f.firstName} onChange={e => setF({ ...f, firstName: e.target.value })}/>
        <input placeholder="Nom" value={f.lastName} onChange={e => setF({ ...f, lastName: e.target.value })}/>
      </div>
      <input placeholder="Adresse" value={f.line1} onChange={e => setF({ ...f, line1: e.target.value })}/>
      {errors.line1 && <p className="error">{errors.line1}</p>}
      <input placeholder="Complément (optionnel)" value={f.line2} onChange={e => setF({ ...f, line2: e.target.value })}/>
      <div className="card-row">
        <input placeholder="Code postal" value={f.postalCode} onChange={e => setF({ ...f, postalCode: e.target.value })}/>
        <input placeholder="Ville" value={f.city} onChange={e => setF({ ...f, city: e.target.value })}/>
      </div>
      {errors.postalCode && <p className="error">{errors.postalCode}</p>}
      {errors.city && <p className="error">{errors.city}</p>}
      <div className="card-row">
        <input placeholder="Région (optionnel)" value={f.region} onChange={e => setF({ ...f, region: e.target.value })}/>
        <input placeholder="Pays" value={f.country} onChange={e => setF({ ...f, country: e.target.value })}/>
      </div>
      <input placeholder="Téléphone (optionnel)" value={f.phone} onChange={e => setF({ ...f, phone: e.target.value })}/>
      {message && <p>{message}</p>}
      <button className="primary">Enregistrer l'adresse</button>
    </form>
  );
}

// Paiements passés : uniquement nom du porteur + 4 derniers chiffres (rien de sensible).
function PaymentsList() {
  const [rows, setRows] = useState([]);
  useEffect(() => { api('/me/payments').then(d => setRows(d.items || [])).catch(() => {}); }, []);
  return (
    <div className="panel">
      <h2>Mes paiements</h2>
      {rows.length === 0 ? <p className="muted">Aucun paiement enregistré.</p> : rows.map(p => (
        <div className="row" key={p.id}>
          <span>{new Date(p.created_at).toLocaleDateString('fr-FR')}</span>
          <span>Carte {p.card_name} •••• {p.card_last4}</span>
          <strong>{Number(p.amount).toFixed(2)} €</strong>
          <Link to={`/commandes/${p.order_id}`}>Commande #{p.order_id}</Link>
        </div>
      ))}
    </div>
  );
}

function Account() {
  const { user } = useAuth();
  const [subs, setSubs] = useState([]);
  useEffect(() => { api('/me/subscriptions').then(d => setSubs(d.items || [])); }, []);
  return (
    <section>
      <h1>Mon compte</h1>
      <p>{user?.email}</p>
      <Link to="/commandes">Mes commandes</Link>
      <PersonalInfoForm/>
      <AddressForm/>
      <PaymentsList/>
      <h2>Mes abonnements</h2>
      {subs.length === 0 ? (
        <p>Aucun abonnement actif pour le moment.</p>
      ) : (
        <div className="grid">
          {subs.map(s => (
            <article className="card" key={s.id}>
              <div>
                <p className="eyebrow">{subscriptionStatusLabel(s)}</p>
                <h2>{s.product_name}</h2>
                <p>Du {new Date(s.starts_at).toLocaleDateString('fr-FR')} au {new Date(s.ends_at).toLocaleDateString('fr-FR')}</p>
              </div>
            </article>
          ))}
        </div>
      )}
      <h2>Sécurité</h2>
      <ChangeEmailForm/>
      <ChangePasswordForm/>
    </section>
  );
}

const ORDER_STATUS_LABELS = { paid: 'Payée', pending: 'En attente', cancelled: 'Annulée' };

function Orders() {
  const [orders, setOrders] = useState([]);
  const [q, setQ] = useState('');
  const [sort, setSort] = useState('date_desc');
  useEffect(() => { api('/me/orders').then(d => setOrders(d.items)); }, []);

  const visible = useMemo(() => {
    let list = orders.filter(o => `${o.id} ${o.first_item || ''} ${o.status}`.toLowerCase().includes(q.toLowerCase()));
    const by = {
      date_desc: (a, b) => new Date(b.created_at) - new Date(a.created_at),
      date_asc: (a, b) => new Date(a.created_at) - new Date(b.created_at),
      total_desc: (a, b) => b.total - a.total,
      total_asc: (a, b) => a.total - b.total,
    }[sort];
    return [...list].sort(by);
  }, [orders, q, sort]);

  return (
    <section>
      <h1>Mes commandes</h1>
      <div className="orders-tools">
        <input placeholder="Rechercher (n°, service, statut...)" value={q} onChange={e => setQ(e.target.value)}/>
        <select value={sort} onChange={e => setSort(e.target.value)}>
          <option value="date_desc">Plus récentes</option>
          <option value="date_asc">Plus anciennes</option>
          <option value="total_desc">Montant décroissant</option>
          <option value="total_asc">Montant croissant</option>
        </select>
      </div>
      {visible.length === 0 && <p className="muted">Aucune commande.</p>}
      {visible.map(o => (
        <Link className="row" to={`/commandes/${o.id}`} key={o.id}>
          <span>Commande #{o.id}</span>
          <span>{o.first_item}{o.items_count > 1 ? ` +${o.items_count - 1}` : ''}</span>
          <span>{new Date(o.created_at).toLocaleDateString('fr-FR')}</span>
          <span>{o.duration_months} mois</span>
          <span className={`badge status-${o.status}`}>{ORDER_STATUS_LABELS[o.status] || o.status}</span>
          <strong>{Number(o.total).toFixed(2)} €</strong>
        </Link>
      ))}
    </section>
  );
}
function OrderDetail() { const { id } = useParams(); const [order, setOrder] = useState(null); useEffect(() => { api(`/me/orders/${id}`).then(setOrder); }, [id]); return <section><h1>Commande #{id}</h1>{order?.items?.map(i => <div className="row" key={i.id}>{i.product_name}<strong>{i.line_total} €</strong></div>)}<Link className="primary" to={`/commandes/${id}/facture`}>Voir la facture</Link></section>; }

function InvoiceView() {
  const { id } = useParams();
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  useEffect(() => { api(`/me/orders/${id}/invoice`).then(setData).catch(err => setError(err.message)); }, [id]);

  if (error) return <section><h1>Facture indisponible</h1><p>{error}</p></section>;
  if (!data) return <p>Chargement...</p>;

  const { invoice, order, user, address, payment } = data;
  return (
    <section className="panel invoice">
      <div className="invoice-actions">
        <button className="primary" onClick={() => window.print()}>Imprimer / Enregistrer en PDF</button>
      </div>
      <h1>Facture {invoice.number}</h1>
      <p>Émise le {new Date(invoice.issued_at).toLocaleDateString('fr-FR')}</p>
      {payment && <p>Payé par carte {payment.card_name} se terminant par •••• {payment.card_last4}</p>}
      <div className="invoice-parties">
        <div>
          <h2>CYNA</h2>
          <p>Services SaaS de cybersécurité</p>
        </div>
        <div>
          <h2>Facturé à</h2>
          <p>{user.firstName} {user.lastName}</p>
          <p>{user.email}</p>
          {address && (
            <>
              {address.company && <p>{address.company}</p>}
              <p>{address.line1}</p>
              <p>{address.postal_code} {address.city}</p>
              <p>{address.country}</p>
            </>
          )}
        </div>
      </div>
      <table className="invoice-table">
        <thead><tr><th>Service</th><th>Durée</th><th>Prix mensuel</th><th>Total</th></tr></thead>
        <tbody>
          {order.items.map(i => (
            <tr key={i.id}>
              <td>{i.product_name}</td>
              <td>{i.duration_months} mois</td>
              <td>{Number(i.unit_monthly_price).toFixed(2)} €</td>
              <td>{Number(i.line_total).toFixed(2)} €</td>
            </tr>
          ))}
        </tbody>
      </table>
      <h2>Total : {Number(invoice.total).toFixed(2)} €</h2>
    </section>
  );
}
// Chatbot de la page contact : réponses par mots-clés, gérées dans le back-office (Chatbot).
function ChatbotWidget() {
  const [responses, setResponses] = useState([]);
  const [messages, setMessages] = useState([{ from: 'bot', text: 'Bonjour ! Posez-moi une question (prix, essai gratuit, factures...) ou utilisez le formulaire pour joindre un conseiller.' }]);
  const [input, setInput] = useState('');
  useEffect(() => { api('/chatbot').then(d => setResponses(d.items || [])).catch(() => {}); }, []);

  const normalize = s => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''); // insensible aux accents
  const ask = e => {
    e.preventDefault();
    const question = input.trim();
    if (!question) return;
    const nq = normalize(question);
    const match = responses.find(r => r.keywords.split(',').some(k => k.trim() && nq.includes(normalize(k.trim()))));
    const answer = match ? match.answer : "Je n'ai pas la réponse à cette question. Laissez-nous un message via le formulaire ci-contre : un conseiller vous répondra sous 24 h.";
    setMessages(m => [...m, { from: 'user', text: question }, { from: 'bot', text: answer }]);
    setInput('');
  };

  return (
    <div className="chatbot panel">
      <h2>Assistant CYNA</h2>
      <div className="chat-log">
        {messages.map((m, i) => <p key={i} className={m.from === 'bot' ? 'chat-bot' : 'chat-user'}>{m.text}</p>)}
      </div>
      <form className="chat-input" onSubmit={ask}>
        <input placeholder="Votre question..." value={input} onChange={e => setInput(e.target.value)}/>
        <button className="primary">Envoyer</button>
      </form>
    </div>
  );
}

function Contact() {
  const [params] = useSearchParams();
  const [sent, setSent] = useState(false);
  // Sujet pré-rempli quand on arrive depuis une fiche produit ("Demander un essai").
  const [form, setForm] = useState({ email: '', subject: params.get('sujet') || '', message: '' });
  return (
    <section className="contact-grid">
      <form className="panel" onSubmit={async e => { e.preventDefault(); await api('/contact', { method: 'POST', body: JSON.stringify(form) }); setSent(true); }}>
        <h1>Contact support</h1>
        <input placeholder="Email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })}/>
        <input placeholder="Sujet" value={form.subject} onChange={e => setForm({ ...form, subject: e.target.value })}/>
        <textarea placeholder="Message" value={form.message} onChange={e => setForm({ ...form, message: e.target.value })}/>
        <button className="primary">Envoyer</button>
        {sent && <p>Message envoyé. Un conseiller vous répondra sous 24 h ouvrées.</p>}
      </form>
      <ChatbotWidget/>
    </section>
  );
}

createRoot(document.getElementById('root')).render(<ErrorBoundary><Router><AuthProvider><Layout/></AuthProvider></Router></ErrorBoundary>);

