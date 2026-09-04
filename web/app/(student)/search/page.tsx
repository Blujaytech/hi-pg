import Link from 'next/link';
import { ApiError } from '@/lib/api';
import { searchPgs, type GenderPreference, type PgSearchResult } from '@/lib/discovery';

export const dynamic = 'force-dynamic';

type SearchPageProps = {
  searchParams: {
    city?: string;
    genderPreference?: GenderPreference;
    minRent?: string;
    maxRent?: string;
    page?: string;
  };
};

export default async function SearchPage({ searchParams }: SearchPageProps) {
  const page = Number.parseInt(searchParams.page ?? '0', 10) || 0;

  let results;
  let errorMessage: string | null = null;
  try {
    results = await searchPgs({
      city: searchParams.city,
      genderPreference: searchParams.genderPreference,
      minRent: searchParams.minRent,
      maxRent: searchParams.maxRent,
      page,
    });
  } catch (error) {
    errorMessage = error instanceof ApiError ? error.message : 'Could not load PG listings right now.';
  }

  return (
    <main className="mx-auto max-w-5xl px-6 py-12">
      <h1 className="text-2xl font-semibold">Find a PG</h1>
      <p className="mt-2 text-slate-600">
        Search active listings by city, gender preference, and monthly rent. Results are live -- availability reflects
        the current bed status, not a cached snapshot.
      </p>

      <form className="mt-6 flex flex-wrap gap-3 rounded-lg border border-slate-200 p-4" method="get">
        <input
          type="text"
          name="city"
          placeholder="City"
          defaultValue={searchParams.city ?? ''}
          className="w-40 rounded-md border border-slate-300 px-3 py-2 text-sm"
        />
        <select
          name="genderPreference"
          defaultValue={searchParams.genderPreference ?? ''}
          className="rounded-md border border-slate-300 px-3 py-2 text-sm"
        >
          <option value="">Any gender preference</option>
          <option value="CO_ED">Co-ed</option>
          <option value="MALE">Male</option>
          <option value="FEMALE">Female</option>
        </select>
        <input
          type="number"
          name="minRent"
          placeholder="Min rent"
          defaultValue={searchParams.minRent ?? ''}
          className="w-32 rounded-md border border-slate-300 px-3 py-2 text-sm"
        />
        <input
          type="number"
          name="maxRent"
          placeholder="Max rent"
          defaultValue={searchParams.maxRent ?? ''}
          className="w-32 rounded-md border border-slate-300 px-3 py-2 text-sm"
        />
        <button type="submit" className="rounded-md bg-brand px-5 py-2 text-sm font-medium text-white">
          Search
        </button>
      </form>

      {errorMessage && <p className="mt-8 text-red-600">{errorMessage}</p>}

      {results && (
        <>
          <p className="mt-6 text-sm text-slate-500">{results.totalElements} PG(s) found</p>
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            {results.content.map((pg) => (
              <PgCard key={pg.id} pg={pg} />
            ))}
          </div>
          {results.content.length === 0 && (
            <p className="mt-8 text-slate-500">No PGs match those filters yet.</p>
          )}
          <Pagination
            page={results.page}
            totalPages={results.totalPages}
            searchParams={searchParams}
          />
        </>
      )}
    </main>
  );
}

function PgCard({ pg }: { pg: PgSearchResult }) {
  return (
    <Link
      href={`/pgs/${pg.id}`}
      className="block rounded-lg border border-slate-200 p-4 transition hover:border-brand hover:shadow-sm"
    >
      <div className="flex items-start justify-between">
        <h2 className="text-lg font-semibold">{pg.name}</h2>
        <span className="rounded-full bg-slate-100 px-2 py-1 text-xs font-medium text-slate-600">
          {pg.genderPreference === 'CO_ED' ? 'Co-ed' : pg.genderPreference}
        </span>
      </div>
      <p className="mt-1 text-sm text-slate-500">
        {pg.address}, {pg.city}
      </p>
      {pg.description && <p className="mt-2 line-clamp-2 text-sm text-slate-600">{pg.description}</p>}
      <div className="mt-3 flex items-center justify-between text-sm">
        <span className={pg.availableBeds > 0 ? 'text-green-700' : 'text-slate-400'}>
          {pg.availableBeds > 0 ? `${pg.availableBeds} bed(s) available` : 'No beds available'}
        </span>
        {pg.minRentPerBed !== null && (
          <span className="font-medium">
            ₹{pg.minRentPerBed.toLocaleString('en-IN')}
            {pg.maxRentPerBed && pg.maxRentPerBed !== pg.minRentPerBed
              ? ` - ₹${pg.maxRentPerBed.toLocaleString('en-IN')}`
              : ''}
            /mo
          </span>
        )}
      </div>
    </Link>
  );
}

function Pagination({
  page,
  totalPages,
  searchParams,
}: {
  page: number;
  totalPages: number;
  searchParams: SearchPageProps['searchParams'];
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
    <div className="mt-8 flex items-center justify-center gap-4 text-sm">
      {page > 0 ? (
        <Link href={buildHref(page - 1)} className="text-brand">
          ← Previous
        </Link>
      ) : (
        <span className="text-slate-300">← Previous</span>
      )}
      <span className="text-slate-500">
        Page {page + 1} of {totalPages}
      </span>
      {page + 1 < totalPages ? (
        <Link href={buildHref(page + 1)} className="text-brand">
          Next →
        </Link>
      ) : (
        <span className="text-slate-300">Next →</span>
      )}
    </div>
  );
}
