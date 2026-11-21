'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import type { DashboardSummary, OwnerSession } from '@/lib/owner-dashboard';

type ViewState = 'checking' | 'signed-out' | 'loading' | 'ready' | 'error';

export function OwnerDashboardExperience() {
  const [view, setView] = useState<ViewState>('checking');
  const [session, setSession] = useState<OwnerSession>({ authenticated: false });
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [message, setMessage] = useState('');

  const loadDashboard = useCallback(async () => {
    setView('loading');
    setMessage('');
    try {
      const response = await fetch('/api/owner/dashboard', { cache: 'no-store' });
      const data = await response.json();
      if (!response.ok) throw new Error(data.message ?? 'Could not load your workspace.');
      setSummary(data as DashboardSummary);
      setView('ready');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Could not load your workspace.';
      if (errorMessage.toLowerCase().includes('sign-in')) {
        setSession({ authenticated: false });
        setView('signed-out');
      } else {
        setMessage(errorMessage);
        setView('error');
      }
    }
  }, []);

  useEffect(() => {
    let active = true;
    async function restoreSession() {
      try {
        const response = await fetch('/api/owner/session', { cache: 'no-store' });
        const data = (await response.json()) as OwnerSession;
        if (!active) return;
        setSession(data);
        if (data.authenticated) await loadDashboard();
        else setView('signed-out');
      } catch {
        if (active) setView('signed-out');
      }
    }
    void restoreSession();
    return () => {
      active = false;
    };
  }, [loadDashboard]);

  async function signOut() {
    await fetch('/api/owner/session', { method: 'DELETE' });
    setSession({ authenticated: false });
    setSummary(null);
    setView('signed-out');
  }

  if (view === 'checking') return <DashboardSkeleton label="Checking your secure workspace" />;
  if (view === 'signed-out') {
    return (
      <OwnerLogin
        onSignedIn={(nextSession) => {
          setSession(nextSession);
          void loadDashboard();
        }}
      />
    );
  }
  if (view === 'loading') return <DashboardSkeleton label="Preparing your portfolio" />;
  if (view === 'error' || !summary) {
    return (
      <DashboardError
        message={message || 'Your owner workspace could not be loaded.'}
        onRetry={loadDashboard}
        onSignOut={signOut}
      />
    );
  }

  return (
    <OwnerDashboard
      summary={summary}
      fullName={session.fullName}
      onRefresh={loadDashboard}
      onSignOut={signOut}
    />
  );
}

function OwnerLogin({ onSignedIn }: { onSignedIn: (session: OwnerSession) => void }) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    setBusy(true);
    setMessage('');
    try {
      const response = await fetch('/api/owner/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: form.get('email'), password: form.get('password') }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.message ?? 'Sign in failed.');
      onSignedIn(data as OwnerSession);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Sign in failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="owner-login-shell">
      <section className="owner-login-story page-enter">
        <span className="eyebrow eyebrow-dark">Hi PG for owners</span>
        <h1>Run every property with a clearer view.</h1>
        <p>
          Occupancy, collections, expenses, customers, and open issues—all summarized from your live Hi PG data.
        </p>
        <div className="owner-proof-grid" aria-label="Owner workspace benefits">
          <Proof icon="chart" title="Live occupancy" text="Know what is full and what is ready." />
          <Proof icon="wallet" title="Clear finances" text="Track collections, dues, and expenses." />
          <Proof icon="shield" title="Protected access" text="Secure owner-only portfolio data." />
        </div>
      </section>

      <section className="owner-login-card page-enter page-enter-delay">
        <div className="owner-login-card-heading">
          <span className="icon-chip"><Icon name="building" /></span>
          <div>
            <p className="eyebrow">Owner workspace</p>
            <h2>Welcome back</h2>
          </div>
        </div>
        <p className="owner-login-copy">Use the same owner account you use in the Hi PG mobile app.</p>
        <form onSubmit={submit} className="owner-login-form">
          <label>
            <span>Email address</span>
            <input name="email" type="email" autoComplete="email" required placeholder="owner@example.com" />
          </label>
          <label>
            <span>Password</span>
            <input name="password" type="password" autoComplete="current-password" required placeholder="Enter your password" />
          </label>
          {message && <div className="form-error" role="alert">{message}</div>}
          <button type="submit" className="premium-button" disabled={busy}>
            {busy ? 'Signing in…' : 'Open owner workspace'}
            {!busy && <Icon name="arrow" />}
          </button>
        </form>
        <div className="secure-note"><Icon name="lock" /> Your session is protected with secure, HTTP-only cookies.</div>
      </section>
    </main>
  );
}

function OwnerDashboard({
  summary,
  fullName,
  onRefresh,
  onSignOut,
}: {
  summary: DashboardSummary;
  fullName?: string;
  onRefresh: () => void;
  onSignOut: () => void;
}) {
  const occupied = percentage(summary.occupiedBeds, summary.totalBeds);
  const available = percentage(summary.availableBeds, summary.totalBeds);
  const maintenance = Math.max(0, 100 - occupied - available);
  const firstName = fullName?.trim().split(/\s+/)[0] || 'Owner';

  return (
    <main className="owner-workspace">
      <section className="owner-dashboard-hero page-enter">
        <div>
          <span className="eyebrow eyebrow-dark"><span className="live-dot" /> Live operations</span>
          <h1>Good to see you, {firstName}.</h1>
          <p>Here is the current health of your Hi PG portfolio.</p>
        </div>
        <div className="owner-hero-actions">
          <button type="button" className="ghost-button ghost-button-dark" onClick={onRefresh}><Icon name="refresh" /> Refresh</button>
          <button type="button" className="ghost-button ghost-button-dark" onClick={onSignOut}><Icon name="logout" /> Sign out</button>
        </div>
      </section>

      <section className="dashboard-grid dashboard-grid-top page-enter page-enter-delay">
        <article className="occupancy-card">
          <div className="card-heading-row">
            <div>
              <p className="eyebrow">Portfolio occupancy</p>
              <h2>{formatPercent(summary.occupancyPercentage)}</h2>
              <span>{summary.occupiedBeds} of {summary.totalBeds} beds occupied</span>
            </div>
            <div
              className="occupancy-ring"
              style={{ '--occupancy': `${Math.min(100, Math.max(0, summary.occupancyPercentage)) * 3.6}deg` } as React.CSSProperties}
              aria-label={`${formatPercent(summary.occupancyPercentage)} occupied`}
            >
              <span>{summary.totalPgs}</span>
              <small>{summary.totalPgs === 1 ? 'property' : 'properties'}</small>
            </div>
          </div>
          <div className="inventory-bar" aria-label="Bed inventory">
            <span className="inventory-occupied" style={{ width: `${occupied}%` }} />
            <span className="inventory-available" style={{ width: `${available}%` }} />
            <span className="inventory-maintenance" style={{ width: `${maintenance}%` }} />
          </div>
          <div className="inventory-legend">
            <Legend tone="occupied" label="Occupied" value={summary.occupiedBeds} />
            <Legend tone="available" label="Available" value={summary.availableBeds} />
            <Legend tone="maintenance" label="Maintenance" value={summary.maintenanceBeds} />
          </div>
        </article>

        <article className="finance-card">
          <div className="card-heading-row compact">
            <div>
              <p className="eyebrow">This month</p>
              <h2>Financial pulse</h2>
            </div>
            <span className={`status-badge ${summary.netThisMonth < 0 ? 'status-danger' : 'status-success'}`}>
              {summary.netThisMonth < 0 ? 'Needs attention' : 'Net positive'}
            </span>
          </div>
          <div className="finance-net">
            <span>Net position</span>
            <strong>{formatMoney(summary.netThisMonth)}</strong>
          </div>
          <div className="finance-rows">
            <FinanceRow label="Collected" value={summary.collectedThisMonth} tone="positive" />
            <FinanceRow label="Expenses" value={summary.expensesThisMonth} tone="neutral" />
            <FinanceRow label="Pending dues" value={summary.totalPendingDues} tone="warning" />
          </div>
        </article>
      </section>

      <section className="metric-grid page-enter page-enter-delay-two" aria-label="Portfolio metrics">
        <Metric icon="building" label="Properties" value={summary.totalPgs} helper={`${summary.totalFloors} floors · ${summary.totalRooms} rooms`} />
        <Metric icon="bed" label="Total beds" value={summary.totalBeds} helper={`${summary.availableBeds} currently available`} />
        <Metric icon="people" label="Active customers" value={summary.totalActiveStudents} helper="Across your portfolio" />
        <Metric icon="alert" label="Open complaints" value={summary.openComplaints} helper={summary.openComplaints > 0 ? 'Review in the mobile app' : 'Everything looks clear'} attention={summary.openComplaints > 0} />
      </section>

      <section className="owner-next-step page-enter page-enter-delay-two">
        <div className="owner-next-step-icon"><Icon name="phone" /></div>
        <div>
          <p className="eyebrow">Operations workspace</p>
          <h2>Manage properties, customers, fees, and complaints in the Hi PG app.</h2>
          <p>The web dashboard currently provides a secure live portfolio overview. Full management remains available in the production mobile experience.</p>
        </div>
        <a href="https://hipg-website.pages.dev" className="premium-button" target="_blank" rel="noreferrer">
          Get the app <Icon name="arrow" />
        </a>
      </section>
    </main>
  );
}

function DashboardSkeleton({ label }: { label: string }) {
  return (
    <main className="owner-workspace" aria-busy="true" aria-label={label}>
      <div className="dashboard-skeleton hero-skeleton" />
      <div className="dashboard-grid dashboard-grid-top">
        <div className="dashboard-skeleton panel-skeleton" />
        <div className="dashboard-skeleton panel-skeleton" />
      </div>
      <div className="metric-grid">
        {[0, 1, 2, 3].map((item) => <div key={item} className="dashboard-skeleton metric-skeleton" />)}
      </div>
      <span className="sr-only">{label}</span>
    </main>
  );
}

function DashboardError({ message, onRetry, onSignOut }: { message: string; onRetry: () => void; onSignOut: () => void }) {
  return (
    <main className="dashboard-message-shell">
      <section className="dashboard-message-card">
        <span className="icon-chip icon-chip-danger"><Icon name="alert" /></span>
        <h1>We could not load your workspace</h1>
        <p>{message}</p>
        <div className="dashboard-message-actions">
          <button type="button" className="premium-button" onClick={onRetry}>Try again</button>
          <button type="button" className="ghost-button" onClick={onSignOut}>Sign out</button>
        </div>
      </section>
    </main>
  );
}

function Proof({ icon, title, text }: { icon: IconName; title: string; text: string }) {
  return <div className="owner-proof"><Icon name={icon} /><div><strong>{title}</strong><span>{text}</span></div></div>;
}

function Metric({ icon, label, value, helper, attention = false }: { icon: IconName; label: string; value: number; helper: string; attention?: boolean }) {
  return (
    <article className={`metric-card ${attention ? 'metric-card-attention' : ''}`}>
      <div className="metric-icon"><Icon name={icon} /></div>
      <div><span>{label}</span><strong>{value.toLocaleString('en-IN')}</strong><small>{helper}</small></div>
    </article>
  );
}

function FinanceRow({ label, value, tone }: { label: string; value: number; tone: 'positive' | 'neutral' | 'warning' }) {
  return <div className="finance-row"><span><i className={`finance-dot finance-dot-${tone}`} />{label}</span><strong>{formatMoney(value)}</strong></div>;
}

function Legend({ tone, label, value }: { tone: string; label: string; value: number }) {
  return <span><i className={`legend-dot legend-${tone}`} />{label}<strong>{value}</strong></span>;
}

type IconName = 'alert' | 'arrow' | 'bed' | 'building' | 'chart' | 'lock' | 'logout' | 'people' | 'phone' | 'refresh' | 'shield' | 'wallet';

function Icon({ name }: { name: IconName }) {
  const paths: Record<IconName, React.ReactNode> = {
    alert: <><path d="M12 9v4" /><path d="M12 17h.01" /><path d="M10.3 3.7 2.6 17a2 2 0 0 0 1.7 3h15.4a2 2 0 0 0 1.7-3L13.7 3.7a2 2 0 0 0-3.4 0Z" /></>,
    arrow: <><path d="M5 12h14" /><path d="m13 6 6 6-6 6" /></>,
    bed: <><path d="M3 7v12" /><path d="M21 19v-7a2 2 0 0 0-2-2H7a4 4 0 0 0-4 4v1h18" /><path d="M7 10V6h5a2 2 0 0 1 2 2v2" /></>,
    building: <><path d="M4 21V5a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v16" /><path d="M17 9h2a2 2 0 0 1 2 2v10" /><path d="M8 7h5M8 11h5M8 15h5M9 21v-3h3v3" /></>,
    chart: <><path d="M4 19V9" /><path d="M10 19V5" /><path d="M16 19v-7" /><path d="M22 19V3" /></>,
    lock: <><rect x="4" y="10" width="16" height="11" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3" /></>,
    logout: <><path d="M10 17l5-5-5-5" /><path d="M15 12H3" /><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4" /></>,
    people: <><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" /></>,
    phone: <><rect x="6" y="2" width="12" height="20" rx="2" /><path d="M10 18h4" /></>,
    refresh: <><path d="M20 6v5h-5" /><path d="M4 18v-5h5" /><path d="M18.5 9a7 7 0 0 0-12-2L4 11M20 13l-2.5 4a7 7 0 0 1-12-2" /></>,
    shield: <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />,
    wallet: <><path d="M4 5h15a2 2 0 0 1 2 2v12H4a2 2 0 0 1-2-2V5a3 3 0 0 1 3-3h13" /><path d="M16 11h5" /></>,
  };
  return <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{paths[name]}</svg>;
}

function percentage(value: number, total: number) {
  return total <= 0 ? 0 : (value / total) * 100;
}

function formatPercent(value: number) {
  return `${value.toLocaleString('en-IN', { maximumFractionDigits: 1 })}%`;
}

function formatMoney(value: number) {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
}
