import Link from 'next/link';
import { HiPgLogo } from '@/components/HiPgLogo';

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="site-footer-inner">
        <div className="site-footer-brand">
          <HiPgLogo inverse />
          <p>Thoughtful PG discovery for students. Clearer operations for owners.</p>
        </div>
        <div className="site-footer-links">
          <div>
            <strong>Discover</strong>
            <Link href="/search">Find a PG</Link>
            <Link href="/?stay=monthly">Monthly stays</Link>
            <Link href="/?stay=flexible">Flexible stays</Link>
          </div>
          <div>
            <strong>Owners</strong>
            <Link href="/dashboard">Owner workspace</Link>
            <a href="https://hipg-website.pages.dev" target="_blank" rel="noreferrer">Download the app</a>
          </div>
          <div>
            <strong>Trust</strong>
            <a href="https://hipg-website.pages.dev/privacy" target="_blank" rel="noreferrer">Privacy</a>
            <a href="https://hipg-website.pages.dev/terms" target="_blank" rel="noreferrer">Terms</a>
            <a href="https://hipg-website.pages.dev/contact" target="_blank" rel="noreferrer">Help &amp; support</a>
          </div>
        </div>
      </div>
      <div className="site-footer-bottom">
        <span>© {new Date().getFullYear()} Hi PG</span>
        <span>Find Your PG. Feel at Home.</span>
      </div>
    </footer>
  );
}

