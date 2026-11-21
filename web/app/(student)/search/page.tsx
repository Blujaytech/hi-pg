import Link from 'next/link';
import { MotionGrid, MotionPage } from '@/components/MotionPrimitives';
import { SearchFiltersPanel, type SearchFilterDefaults } from '@/components/SearchFiltersPanel';
import { ApiError } from '@/lib/api';
import { searchPgs, type GenderPreference, type PgSearchResult } from '@/lib/discovery';

export const dynamic = 'force-dynamic';

type SearchPageProps = {
  searchParams: Promise<{
    city?: string;
    genderPreference?: GenderPreference;
    minRent?: string;
    maxRent?: string;
    page?: string;
  }>;
};

export default async function SearchPage({ searchParams }: SearchPageProps) {
  const filters = await searchParams;
  const page = Number.parseInt(filters.page ?? '0', 10) || 0;

  let results;
  let errorMessage: string | null = null;
  try {
    results = await searchPgs({
      city: filters.city,
      genderPreference: filters.genderPreference,
      minRent: filters.minRent,
      maxRent: filters.maxRent,
      page,
    });
  } catch (error) {
    errorMessage = error instanceof ApiError ? error.message : 'Could not load PG listings right now.';
  }

  const defaults: SearchFilterDefaults = {
    city: filters.city,
    genderPreference: filters.genderPreference,
    minRent: filters.minRent,
    maxRent: filters.maxRent,
  };

  return (
    <MotionPage>
      <main className="discovery-results-page">
        <section className="search-page-hero">
          <div className="search-page-hero-inner">
            <div>
              <p className="eyebrow">Find your next stay</p>
              <h1>PGs that fit your life.</h1>
              <p>Compare real prices, room configurations, and current availability before you decide.</p>
            </div>
            <form action="/search" method="get" className="compact-search-bar">
              <label>
                <span>Where</span>
                <input name="city" defaultValue={filters.city ?? ''} placeholder="Search by city" />
              </label>
              {filters.genderPreference && <input type="hidden" name="genderPreference" value={filters.genderPreference} />}
              {filters.minRent && <input type="hidden" name="minRent" value={filters.minRent} />}
              {filters.maxRent && <input type="hidden" name="maxRent" value={filters.maxRent} />}
              <button type="submit" aria-label="Search">
                <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="11" cy="11" r="7" /><path d="m20 20-4-4" /></svg>
              </button>
            </form>
          </div>
        </section>

        <section className="search-results-shell" aria-labelledby="search-results-title">
          <div className="search-toolbar">
            <div>
              <h2 id="search-results-title">{filters.city ? `Stays in ${filters.city}` : 'Explore available PGs'}</h2>
              {results && <p aria-live="polite">{results.totalElements} {results.totalElements === 1 ? 'property' : 'properties'} found</p>}
            </div>
            <SearchFiltersPanel defaults={defaults} />
          </div>

          <ActiveFilters filters={filters} />

          {errorMessage && (
            <div role="alert" className="mt-5 rounded-panel border border-red-200 bg-red-50 p-5 text-sm text-red-700">
              <p className="font-bold">We could not load listings.</p>
              <p className="mt-1">{errorMessage}</p>
            </div>
          )}

          {results && (
            <>
              <MotionGrid className="property-discovery-grid">
                {results.content.map((pg) => <PgCard key={pg.id} pg={pg} />)}
              </MotionGrid>
              {results.content.length === 0 && (
                <div className="search-empty-state">
                  <div className="search-empty-icon">
                    <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="11" cy="11" r="7" /><path d="m20 20-4-4M8 11h6" /></svg>
                  </div>
                  <h3>No PGs match these filters</h3>
                  <p>Try another city or widen your monthly budget.</p>
                  <Link href="/search">Clear all filters</Link>
                </div>
              )}
              <Pagination page={results.page} totalPages={results.totalPages} searchParams={filters} />
            </>
          )}
        </section>
      </main>
    </MotionPage>
  );
}

function PgCard({ pg }: { pg: PgSearchResult }) {
  const price = pg.minRentPerBed !== null ? formatRupees(pg.minRentPerBed) : null;
  const place = [pg.address, pg.city].filter(Boolean).join(', ');

  return (
    <Link
      href={`/pgs/${pg.id}`}
      className="airbnb-property-card group"
    >
      <div
        role="img"
        aria-label={pg.photoUrl ? `${pg.name} property` : `${pg.name} photo placeholder`}
        className={`airbnb-property-image ${pg.photoUrl ? '' : 'property-placeholder'}`}
        style={pg.photoUrl ? { backgroundImage: `url(${JSON.stringify(pg.photoUrl)})` } : undefined}
      >
        <span className="property-category-badge">
          {genderLabel(pg.genderPreference)}
        </span>
        <span className={`property-verification-badge ${pg.verified ? 'property-verified' : 'property-unverified'}`}>
          {pg.verified ? 'Verified' : 'Verification pending'}
        </span>
      </div>

      <div className="airbnb-property-copy">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h3>{pg.name}</h3>
            <p>{place}</p>
          </div>
        </div>

        <div className="property-facts">
          {pg.offersMonthly && <span>Monthly</span>}
          {pg.offersDayWise && <span>Day-wise</span>}
          {pg.verified && <span>{pg.availableBeds} {pg.availableBeds === 1 ? 'bed' : 'beds'} free</span>}
        </div>

        <div className="property-price-row">
          <div className="min-w-0">
            {price ? (
              <p>
                <strong>{price}</strong><span> / month</span>
              </p>
            ) : (
              <p className="property-price-muted">Price available in details</p>
            )}
          </div>
          <span className={`availability-dot-label ${pg.verified && pg.availableBeds > 0 ? 'availability-open' : ''}`}>
            <i />{!pg.verified ? 'View details' : pg.availableBeds > 0 ? 'Available' : 'Full now'}
          </span>
        </div>
      </div>
    </Link>
  );
}

function ActiveFilters({ filters }: { filters: Awaited<SearchPageProps['searchParams']> }) {
  const labels = [
    filters.genderPreference ? genderLabel(filters.genderPreference) : null,
    filters.minRent ? `From ${formatRupees(Number(filters.minRent))}` : null,
    filters.maxRent ? `Up to ${formatRupees(Number(filters.maxRent))}` : null,
  ].filter(Boolean) as string[];
  if (labels.length === 0) return null;
  return <div className="active-filter-chips">{labels.map((label) => <span key={label}>{label}</span>)}</div>;
}

function genderLabel(gender: GenderPreference) {
  if (gender === 'MALE') return 'Men';
  if (gender === 'FEMALE') return 'Women';
  if (gender === 'CO_ED') return 'Co-living';
  return 'PG';
}

function formatRupees(value: number) {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
}

function Pagination({
  page,
  totalPages,
  searchParams,
}: {
  page: number;
  totalPages: number;
  searchParams: Awaited<SearchPageProps['searchParams']>;
}) {
  if (totalPages <= 1) return null;

  const buildHref = (targetPage: number) => {
    const params = new URLSearchParams();
    if (searchParams.city) params.set('city', searchParams.city);
    if (searchParams.genderPreference) params.set('genderPreference', searchParams.genderPreference);
    if (searchParams.minRent) params.set('minRent', searchParams.minRent);
    if (searchParams.maxRent) params.set('maxRent', searchParams.maxRent);
    params.set('page', String(targetPage));
    return `/search?${params.toString()}`;
  };

  return (
    <nav className="mt-8 flex items-center justify-center gap-4 text-sm" aria-label="Search result pages">
      {page > 0 ? (
        <Link href={buildHref(page - 1)} className="inline-flex min-h-11 items-center rounded-card border border-line bg-white px-4 font-bold text-brand-text">
          ← Previous
        </Link>
      ) : (
        <span className="inline-flex min-h-11 items-center px-4 text-slate-300">← Previous</span>
      )}
      <span className="text-slate-500">Page {page + 1} of {totalPages}</span>
      {page + 1 < totalPages ? (
        <Link href={buildHref(page + 1)} className="inline-flex min-h-11 items-center rounded-card border border-line bg-white px-4 font-bold text-brand-text">
          Next →
        </Link>
      ) : (
        <span className="inline-flex min-h-11 items-center px-4 text-slate-300">Next →</span>
      )}
    </nav>
  );
}
