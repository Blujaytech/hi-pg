import Link from 'next/link';

/**
 * Public landing page. Student-facing PG search/listing (technical plan §6
 * Phase 9) lives under app/(student)/ as server components for SEO,
 * fetching straight from the public, unauthenticated `/public/pgs`
 * endpoints -- see lib/discovery.ts and docs/api.md.
 */
export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col items-center justify-center gap-6 px-6 text-center">
      <h1 className="text-4xl font-bold">PG Platform</h1>
      <p className="max-w-xl text-slate-600">
        Discover verified PG accommodation, or manage your own PG property -- floors, rooms, beds, fees, and more.
      </p>
      <div className="flex gap-4">
        <Link href="/search" className="rounded-md bg-brand px-5 py-3 font-medium text-white">
          Find a PG
        </Link>
        <Link href="/dashboard" className="rounded-md border border-slate-300 px-5 py-3 font-medium">
          Owner console
        </Link>
      </div>
      <p className="mt-8 text-sm text-slate-400">
        The owner web console isn&apos;t built yet -- use the Flutter Owner app for that. Student search/browse is
        live here. See PG_PLATFORM_TECHNICAL_PLAN.md §6.
      </p>
    </main>
  );
}
