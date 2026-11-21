import Link from 'next/link';
import { ApiError } from '@/lib/api';
import { searchPgs, type GenderPreference, type PgSearchResult } from '@/lib/discovery';

export const dynamic = 'force-dynamic';

const categoryLinks: Array<{
  label: string;
  description: string;
  href: string;
  symbol: 'men' | 'women' | 'coliving' | 'all';
}> = [
  { label: 'Men\'s PG', description: 'Comfortable stays for men', href: '/search?genderPreference=MALE', symbol: 'men' },
  { label: 'Women\'s PG', description: 'Thoughtful stays for women', href: '/search?genderPreference=FEMALE', symbol: 'women' },
  { label: 'Co-living', description: 'Flexible shared living', href: '/search?genderPreference=CO_ED', symbol: 'coliving' },
  { label: 'All PGs', description: 'Explore every published stay', href: '/search', symbol: 'all' },
];

export default async function HomePage() {
  const requests = await Promise.allSettled([
    searchPgs({ size: 12 }),
    searchPgs({ genderPreference: 'MALE', size: 12 }),
    searchPgs({ genderPreference: 'FEMALE', size: 12 }),
    searchPgs({ genderPreference: 'CO_ED', size: 12 }),
  ]);

  const [all, men, women, coliving] = requests.map((request) =>
    request.status === 'fulfilled' ? request.value.content : [],
  );
  const firstError = requests.find((request) => request.status === 'rejected');
  const errorMessage =
    requests.every((request) => request.status === 'rejected') && firstError?.status === 'rejected'
      ? firstError.reason instanceof ApiError
        ? firstError.reason.message
        : 'Property discovery is temporarily unavailable.'
      : null;

  const sections = [
    { title: 'Stays to explore', subtitle: 'Published PGs from Hi PG', pgs: all, href: '/search' },
    { title: 'Men\'s PGs', subtitle: 'Properties listed for men', pgs: men, href: '/search?genderPreference=MALE' },
    { title: 'Women\'s PGs', subtitle: 'Properties listed for women', pgs: women, href: '/search?genderPreference=FEMALE' },
    { title: 'Co-living spaces', subtitle: 'Published co-living properties', pgs: coliving, href: '/search?genderPreference=CO_ED' },
  ].filter((section) => section.pgs.length > 0);

  return (
    <main>
      <section className="discovery-hero">
        <div className="discovery-hero-inner">
          <div className="discovery-hero-copy page-enter">
            <p className="eyebrow eyebrow-dark">Find Your PG. Feel at Home.</p>
            <h1>A better place to begin your next chapter.</h1>
            <p className="discovery-hero-description">
              Discover published PGs, compare transparent prices, and understand real availability before you decide.
            </p>

            <form action="/search" method="get" className="discovery-search">
              <label>
                <span className="discovery-search-icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z" /><circle cx="12" cy="10" r="2.5" /></svg>
                </span>
                <span className="sr-only">City</span>
                <input name="city" type="search" placeholder="Search Hyderabad, Chennai, Bengaluru…" />
              </label>
              <button type="submit" aria-label="Search PGs">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="11" cy="11" r="7" /><path d="m20 20-4-4" /></svg>
                <span>Search stays</span>
              </button>
            </form>

            <div className="discovery-hero-points">
              <span><i>✓</i> Browse freely</span>
              <span><i>✓</i> Real listing prices</span>
              <span><i>✓</i> Live bed signals</span>
            </div>
          </div>
          <HeroPropertyCollage properties={all} />
        </div>
      </section>

      <section className="trust-strip page-enter page-enter-delay" aria-label="Why choose Hi PG">
        <TrustItem title="Verified" text="Owner and property checks" icon="shield" />
        <TrustItem title="Map-ready" text="Clear location and routes" icon="map" />
        <TrustItem title="Clear pricing" text="No guessing before you visit" icon="price" />
      </section>

      <section className="mx-auto max-w-content px-4 py-8 sm:px-6 lg:px-8">
        <SectionHeading title="Find your kind of stay" subtitle="Explore spaces shaped around your routine" />
        <div className="hide-scrollbar -mx-4 mt-4 flex snap-x gap-3 overflow-x-auto px-4 pb-2 sm:mx-0 sm:grid sm:grid-cols-2 sm:px-0 lg:grid-cols-4">
          {categoryLinks.map((category) => (
            <Link
              key={category.label}
              href={category.href}
              className="stay-category-card flex min-w-[230px] snap-start items-center gap-4 rounded-card border border-slate-200 bg-white p-4 shadow-card transition hover:-translate-y-0.5 hover:border-brand sm:min-w-0"
            >
              <span aria-hidden="true" className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-brand-soft text-base font-extrabold text-brand-text">
                <CategoryIcon name={category.symbol} />
              </span>
              <span>
                <strong className="block text-base text-ink">{category.label}</strong>
                <span className="mt-1 block text-sm text-slate-500">{category.description}</span>
              </span>
            </Link>
          ))}
        </div>
      </section>

      <section className="mx-auto max-w-content space-y-10 px-4 pb-12 sm:px-6 lg:px-8">
        {errorMessage && <DiscoveryError message={errorMessage} />}
        {!errorMessage && sections.length === 0 && <DiscoveryEmpty />}
        {sections.map((section) => (
          <PropertyRail key={section.title} {...section} />
        ))}
      </section>

      <section className="border-t border-slate-200 bg-white">
        <div className="mx-auto flex max-w-content flex-col gap-5 px-4 py-10 sm:px-6 md:flex-row md:items-center md:justify-between lg:px-8">
          <div>
            <h2 className="text-2xl font-extrabold tracking-tight text-ink">Ready to explore your next stay?</h2>
            <p className="mt-2 text-slate-600">View all published properties and use the available search filters.</p>
          </div>
          <Link href="/search" className="inline-flex min-h-12 items-center justify-center rounded-card bg-brand px-6 font-bold text-white transition hover:bg-brand-pressed">
            Explore all PGs
          </Link>
        </div>
      </section>
    </main>
  );
}

function HeroPropertyCollage({ properties }: { properties: PgSearchResult[] }) {
  const featured = properties.filter((property) => property.photoUrl).slice(0, 3);
  return (
    <div className="hero-property-collage page-enter page-enter-delay" aria-label="Featured Hi PG properties">
      {[0, 1, 2].map((index) => {
        const property = featured[index];
        return (
          <div
            key={property?.id ?? index}
            className={`hero-property-tile hero-property-tile-${index + 1} ${property?.photoUrl ? '' : 'property-placeholder'}`}
            style={property?.photoUrl ? { backgroundImage: `url(${JSON.stringify(property.photoUrl)})` } : undefined}
          >
            {property && (
              <div className="hero-property-caption">
                <strong>{property.name}</strong>
                <span>{property.city}</span>
              </div>
            )}
          </div>
        );
      })}
      <div className="hero-floating-note"><span className="live-dot" /> Live availability</div>
    </div>
  );
}

function TrustItem({ title, text, icon }: { title: string; text: string; icon: 'shield' | 'map' | 'price' }) {
  const paths = {
    shield: <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />,
    map: <><path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3Z" /><path d="M9 3v15M15 6v15" /></>,
    price: <><path d="M6 2v20M18 2v20" /><path d="M4 6h10a4 4 0 0 1 0 8H8l8 6" /></>,
  };
  return (
    <div className="trust-item">
      <span><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{paths[icon]}</svg></span>
      <div><strong>{title}</strong><small>{text}</small></div>
    </div>
  );
}

function CategoryIcon({ name }: { name: 'men' | 'women' | 'coliving' | 'all' }) {
  const paths = {
    men: <><circle cx="12" cy="8" r="3" /><path d="M6 21v-2a6 6 0 0 1 12 0v2M16 4l4-2M17 2h3v3" /></>,
    women: <><circle cx="12" cy="8" r="3" /><path d="M6 21v-2a6 6 0 0 1 12 0v2M12 11v6M9.5 14.5h5" /></>,
    coliving: <><circle cx="8" cy="8" r="2.5" /><circle cx="16" cy="8" r="2.5" /><path d="M3 20v-1a5 5 0 0 1 10 0v1M11 20v-1a5 5 0 0 1 10 0v1" /></>,
    all: <><path d="M4 21V7l8-4 8 4v14" /><path d="M8 11h2M14 11h2M8 15h2M14 15h2M10 21v-3h4v3" /></>,
  };
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{paths[name]}</svg>;
}

function SectionHeading({ title, subtitle, href }: { title: string; subtitle: string; href?: string }) {
  return (
    <div className="flex items-end justify-between gap-4">
      <div>
        <h2 className="text-xl font-extrabold tracking-tight text-ink sm:text-2xl">{title}</h2>
        <p className="mt-1 text-sm text-slate-500">{subtitle}</p>
      </div>
      {href && (
        <Link href={href} className="shrink-0 rounded-lg px-3 py-2 text-sm font-bold text-brand-text hover:bg-brand-soft">
          See all
        </Link>
      )}
    </div>
  );
}

function PropertyRail({ title, subtitle, pgs, href }: { title: string; subtitle: string; pgs: PgSearchResult[]; href: string }) {
  return (
    <section>
      <SectionHeading title={title} subtitle={subtitle} href={href} />
      <div
        role="region"
        aria-label={`${title} properties`}
        tabIndex={0}
        className="hide-scrollbar -mx-4 mt-4 flex snap-x gap-4 overflow-x-auto px-4 pb-3 sm:mx-0 sm:px-0"
      >
        {pgs.map((pg) => (
          <PropertyCard key={pg.id} pg={pg} />
        ))}
      </div>
    </section>
  );
}

function PropertyCard({ pg }: { pg: PgSearchResult }) {
  const gender = genderLabel(pg.genderPreference);
  const rent = pg.minRentPerBed === null ? null : formatMoney(pg.minRentPerBed);
  return (
    <Link
      href={`/pgs/${pg.id}`}
      className="group min-w-[270px] max-w-[270px] snap-start overflow-hidden rounded-card border border-slate-200 bg-white shadow-card transition hover:-translate-y-1 hover:border-brand sm:min-w-[300px] sm:max-w-[300px]"
    >
      <div
        className="relative h-44 bg-ink bg-cover bg-center"
        style={pg.photoUrl ? { backgroundImage: `url(${JSON.stringify(pg.photoUrl).slice(1, -1)})` } : undefined}
      >
        {!pg.photoUrl && (
          <div aria-hidden="true" className="flex h-full items-center justify-center text-center text-white/80">
            <span className="rounded-card border border-white/20 bg-white/10 px-4 py-3 text-sm font-bold">Hi PG property</span>
          </div>
        )}
        <div className="absolute left-3 top-3 rounded-md bg-ink/90 px-2 py-1 text-[11px] font-extrabold uppercase tracking-wide text-white">
          {gender}
        </div>
        <div className={`absolute right-3 top-3 rounded-md px-2 py-1 text-[11px] font-extrabold uppercase tracking-wide text-white ${pg.verified ? 'bg-success' : 'bg-warning'}`}>
          {pg.verified ? 'Verified' : 'Unverified'}
        </div>
      </div>
      <div className="p-4">
        <h3 className="truncate text-base font-extrabold text-ink group-hover:text-brand-text">{pg.name}</h3>
        <p className="mt-1 line-clamp-2 min-h-10 text-sm leading-5 text-slate-500">{pg.address}, {pg.city}</p>
        <div className="mt-3 flex flex-wrap gap-2">
          {pg.offersMonthly && <StayTag>Monthly</StayTag>}
          {pg.offersDayWise && <StayTag>Day-wise</StayTag>}
        </div>
        <div className="mt-4 flex items-end justify-between gap-3 border-t border-slate-100 pt-3">
          <div>
            {pg.verified && rent ? (
              <>
                <span className="block text-xs text-slate-500">Starts from</span>
                <strong className="text-lg text-ink">{rent}<span className="text-xs font-medium text-slate-500"> / month</span></strong>
              </>
            ) : (
              <span className="text-sm font-semibold text-slate-600">View listing details</span>
            )}
          </div>
          {pg.verified && (
            <span className={`text-right text-xs font-bold ${pg.availableBeds > 0 ? 'text-success' : 'text-slate-400'}`}>
              {pg.availableBeds > 0 ? `${pg.availableBeds} bed${pg.availableBeds === 1 ? '' : 's'} free` : 'Full now'}
            </span>
          )}
        </div>
      </div>
    </Link>
  );
}

function StayTag({ children }: { children: React.ReactNode }) {
  return <span className="rounded-md bg-brand-soft px-2 py-1 text-xs font-bold text-brand-text">{children}</span>;
}

function DiscoveryError({ message }: { message: string }) {
  return (
    <div className="rounded-panel border border-red-200 bg-white p-6 text-center shadow-card">
      <h2 className="text-lg font-extrabold text-ink">Couldn&apos;t load properties</h2>
      <p className="mt-2 text-sm text-slate-600">{message}</p>
      <Link href="/" className="mt-4 inline-flex min-h-11 items-center rounded-card border border-slate-300 px-5 text-sm font-bold text-ink hover:border-brand">
        Try again
      </Link>
    </div>
  );
}

function DiscoveryEmpty() {
  return (
    <div className="rounded-panel border border-slate-200 bg-white p-8 text-center shadow-card">
      <h2 className="text-xl font-extrabold text-ink">No PGs are published yet</h2>
      <p className="mt-2 text-slate-600">Use search to check another city or return when more listings are available.</p>
      <Link href="/search" className="mt-5 inline-flex min-h-12 items-center rounded-card bg-brand px-6 font-bold text-white hover:bg-brand-pressed">
        Open search
      </Link>
    </div>
  );
}

function genderLabel(gender: GenderPreference) {
  if (gender === 'MALE') return 'Men';
  if (gender === 'FEMALE') return 'Women';
  if (gender === 'CO_ED') return 'Co-living';
  return 'PG';
}

function formatMoney(amount: number) {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(amount);
}
