import type { Metadata } from 'next';
import Link from 'next/link';
import { HiPgLogo } from '@/components/HiPgLogo';
import { SiteFooter } from '@/components/SiteFooter';
import './globals.css';

export const metadata: Metadata = {
  title: 'Hi PG | Find Your PG. Feel at Home.',
  description: 'Discover PG accommodation, compare real prices, and view live property availability.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-canvas text-ink antialiased">
        <a
          href="#main-content"
          className="fixed left-4 top-4 z-[100] -translate-y-24 rounded-card bg-ink px-4 py-3 text-sm font-bold text-white shadow-floating transition focus:translate-y-0"
        >
          Skip to main content
        </a>
        <header className="site-header">
          <div className="mx-auto flex h-[4.5rem] max-w-content items-center justify-between px-4 sm:px-6 lg:px-8">
            <Link href="/" aria-label="Hi PG home">
              <HiPgLogo />
            </Link>
            <nav className="hidden items-center gap-1 md:flex" aria-label="Primary navigation">
              <HeaderLink href="/">Home</HeaderLink>
              <HeaderLink href="/search">Find a PG</HeaderLink>
              <HeaderLink href="/dashboard">For owners</HeaderLink>
            </nav>
            <div className="flex items-center gap-2">
              <Link href="/dashboard" className="hidden min-h-11 items-center rounded-xl border border-line px-4 text-sm font-bold text-ink transition hover:border-brand hover:text-brand-text sm:inline-flex">
                Owner sign in
              </Link>
              <Link href="/search" className="inline-flex min-h-11 items-center rounded-xl bg-brand px-4 text-sm font-bold text-white transition hover:bg-brand-pressed md:hidden">
                Search
              </Link>
            </div>
          </div>
        </header>
        <div id="main-content" tabIndex={-1} className="pb-20 md:pb-0">
          {children}
        </div>
        <SiteFooter />
        <nav
          className="fixed inset-x-0 bottom-0 z-50 grid h-16 grid-cols-3 border-t border-slate-200 bg-white px-2 shadow-[0_-4px_16px_rgba(51,53,69,0.07)] md:hidden"
          aria-label="Mobile navigation"
        >
          <MobileNavLink href="/" label="Home" icon="home" />
          <MobileNavLink href="/search" label="Explore" icon="search" />
          <MobileNavLink href="/dashboard" label="Owners" icon="building" />
        </nav>
      </body>
    </html>
  );
}

function HeaderLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="inline-flex min-h-11 items-center rounded-lg px-4 text-sm font-semibold text-ink transition hover:bg-brand-soft hover:text-brand-text"
    >
      {children}
    </Link>
  );
}

function MobileNavLink({ href, label, icon }: { href: string; label: string; icon: 'home' | 'search' | 'building' }) {
  const path = {
    home: 'M3 10.5 12 3l9 7.5V21a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1V10.5Z',
    search: 'm21 21-4.35-4.35m2.35-5.65a8 8 0 1 1-16 0 8 8 0 0 1 16 0Z',
    building: 'M4 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16m0-12h3a1 1 0 0 1 1 1v11M8 7h4M8 11h4M8 15h4M9 21v-3h2v3',
  }[icon];
  return (
    <Link href={href} className="flex min-h-12 flex-col items-center justify-center gap-1 text-xs font-semibold text-slate-600 hover:text-brand">
      <svg aria-hidden="true" viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d={path} />
      </svg>
      {label}
    </Link>
  );
}
