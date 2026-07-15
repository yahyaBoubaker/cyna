import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Link, Navigate, Route, BrowserRouter as Router, Routes, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { Shield, ShoppingCart, User, Search, LogOut } from 'lucide-react';
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
  const logout = () => {
    localStorage.removeItem('cyna_token');
    localStorage.removeItem('cyna_user');
    setUser(null);
  };
  return <AuthContext.Provider value={{ user, login, verify2fa, register, logout }}>{children}</AuthContext.Provider>;
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
  return <><header><Link className="brand" to="/"><Shield/> CYNA</Link><nav><Link to="/catalogue">Catalogue</Link><Link to="/contact">Contact</Link><Link to="/panier"><ShoppingCart/> {count}</Link>{user ? <><Link to="/compte"><User/> {user.firstName || 'Compte'}</Link><button onClick={logout}><LogOut size={16}/> Quitter</button></> : <Link to="/login">Connexion</Link>}</nav></header><main><Routes><Route path="/" element={<Home/>}/><Route path="/catalogue" element={<Catalogue/>}/><Route path="/categorie/:id" element={<Category/>}/><Route path="/recherche" element={<SearchPage/>}/><Route path="/produits/:id" element={<ProductDetail/>}/><Route path="/panier" element={<Cart/>}/><Route path="/checkout" element={<Protected><Checkout/></Protected>}/><Route path="/login" element={<Login/>}/><Route path="/register" element={<Register/>}/><Route path="/verifier-email" element={<VerifyEmail/>}/><Route path="/confirmer-email" element={<ConfirmEmailChange/>}/><Route path="/mot-de-passe-oublie" element={<Forgot/>}/><Route path="/compte" element={<Protected><Account/></Protected>}/><Route path="/commandes" element={<Protected><Orders/></Protected>}/><Route path="/commandes/:id" element={<Protected><OrderDetail/></Protected>}/><Route path="/commandes/:id/facture" element={<Protected><InvoiceView/></Protected>}/><Route path="/contact" element={<Contact/>}/></Routes></main><footer>CYNA - SaaS cybersecurity commerce</footer></>;
}

function Protected({ children }) {
  return useAuth().user ? children : <Navigate to="/login"/>;
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
            <span className="eyebrow">{c.name}</span>
            <p>{c.description}</p>
          </Link>
        ))}
      </div>
    </section>
  );
}

function Home() {
  const [slides, setSlides] = useState([]);
  const [categories, setCategories] = useState([]);
  const [featured, setFeatured] = useState([]);
  useEffect(() => {
    api('/home-carousel').then(d => setSlides(d.items || [])).catch(() => setSlides([]));
    api('/categories').then(d => setCategories(d.items || [])).catch(() => setCategories([]));
    api('/featured-products').then(d => setFeatured(d.items || [])).catch(() => setFeatured([]));
  }, []);
  return (
    <>
      {slides.length > 0 ? (
        <Carousel slides={slides}/>
      ) : (
        <section className="hero"><div><p className="eyebrow">SOC - EDR - XDR</p><h1>CYNA Cybersecurity SaaS</h1><p>Des services cyber managés pour protéger les entreprises avec une plateforme claire, mesurable et prête pour l'abonnement.</p><Link className="primary" to="/catalogue">Voir les services</Link></div></section>
      )}
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
  useEffect(() => { api(`/products/${id}`).then(setP); }, [id]);
  if (!p) return <p>Chargement...</p>;
  const add = () => { const items = cartItems(); items.push({ productId: p.id, name: p.name, monthlyPrice: Number(p.monthly_price), quantity: 1, durationMonths: duration }); saveCart(items); };
  return <section className="detail"><ProductIllustrationsCarousel images={p.images || []}/><div><p className="eyebrow">{p.category_name}</p><h1>{p.name}</h1><p>{p.description}</p><label>Durée<select value={duration} onChange={e => setDuration(Number(e.target.value))}><option value="1">1 mois</option><option value="12">12 mois</option><option value="24">24 mois</option></select></label><strong>{(Number(p.monthly_price) * duration).toFixed(2)} €</strong><button className="primary" onClick={add}>Ajouter au panier</button></div></section>;
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
  const [done, setDone] = useState(null);
  const [address, setAddress] = useState({ company: '', line1: '', city: '', postalCode: '', country: 'France' });
  const [payment, setPayment] = useState({ cardName: '', cardNumber: '', cardExpiry: '', cvv: '' });
  const [errors, setErrors] = useState({});
  const [globalError, setGlobalError] = useState('');

  useEffect(() => {
    api('/me/address').then(d => { if (d.address) setAddress({
      company: d.address.company || '',
      line1: d.address.line1 || '',
      city: d.address.city || '',
      postalCode: d.address.postal_code || '',
      country: d.address.country || 'France',
    }); }).catch(() => {});
  }, []);

  const submit = async () => {
    setGlobalError('');
    const nextErrors = {};
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
      <input placeholder="Société (optionnel)" value={address.company} onChange={e => setAddress({ ...address, company: e.target.value })}/>
      <input placeholder="Adresse" value={address.line1} onChange={e => setAddress({ ...address, line1: e.target.value })}/>
      {errors.line1 && <p className="error">{errors.line1}</p>}
      <input placeholder="Ville" value={address.city} onChange={e => setAddress({ ...address, city: e.target.value })}/>
      {errors.city && <p className="error">{errors.city}</p>}
      <input placeholder="Code postal" value={address.postalCode} onChange={e => setAddress({ ...address, postalCode: e.target.value })}/>
      {errors.postalCode && <p className="error">{errors.postalCode}</p>}
      <input placeholder="Pays" value={address.country} onChange={e => setAddress({ ...address, country: e.target.value })}/>

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

function Login() {
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
      navigate('/compte');
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
  const [state, setState] = useState({ loading: true, message: '', ok: false });

  useEffect(() => {
    const token = params.get('token') || '';
    api(`/auth/verify?token=${encodeURIComponent(token)}`)
      .then(data => setState({ loading: false, message: data.message, ok: true }))
      .catch(err => setState({ loading: false, message: err.message, ok: false }));
  }, [params]);

  if (state.loading) return <section><h1>Vérification en cours...</h1></section>;
  return (
    <section className="panel">
      <h1>{state.ok ? 'Compte confirmé' : 'Lien invalide'}</h1>
      <p>{state.message}</p>
      {state.ok && <Link className="primary" to="/login">Se connecter</Link>}
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

function Forgot() { return <section><h1>Mot de passe oublié</h1><p>Flux prêt côté interface. L'envoi d'e-mail reste à brancher côté backend.</p></section>; }
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

function Account() {
  const { user } = useAuth();
  const [subs, setSubs] = useState([]);
  useEffect(() => { api('/me/subscriptions').then(d => setSubs(d.items || [])); }, []);
  return (
    <section>
      <h1>Mon compte</h1>
      <p>{user?.email}</p>
      <Link to="/commandes">Mes commandes</Link>
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

function Orders() { const [orders, setOrders] = useState([]); useEffect(() => { api('/me/orders').then(d => setOrders(d.items)); }, []); return <section><h1>Mes commandes</h1>{orders.map(o => <Link className="row" to={`/commandes/${o.id}`} key={o.id}>Commande #{o.id} - {o.total} €</Link>)}</section>; }
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
function Contact() { const [sent, setSent] = useState(false); const [form, setForm] = useState({ email: '', subject: '', message: '' }); return <form className="panel" onSubmit={async e => { e.preventDefault(); await api('/contact', { method: 'POST', body: JSON.stringify(form) }); setSent(true); }}><h1>Contact support</h1><input placeholder="Email" onChange={e => setForm({ ...form, email: e.target.value })}/><input placeholder="Sujet" onChange={e => setForm({ ...form, subject: e.target.value })}/><textarea placeholder="Message" onChange={e => setForm({ ...form, message: e.target.value })}/><button className="primary">Envoyer</button>{sent && <p>Message envoyé.</p>}</form>; }

createRoot(document.getElementById('root')).render(<ErrorBoundary><Router><AuthProvider><Layout/></AuthProvider></Router></ErrorBoundary>);

