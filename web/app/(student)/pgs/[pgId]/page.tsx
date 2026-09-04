import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ApiError } from '@/lib/api';
import { getPgDetails } from '@/lib/discovery';
import { LiveAvailabilityBadge } from '@/components/LiveAvailabilityBadge';

export const dynamic = 'force-dynamic';

export default async function PgDetailsPage({ params }: { params: { pgId: string } }) {
  let pg;
  try {
    pg = await getPgDetails(params.pgId);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) {
      notFound();
    }
    throw error;
  }

  return (
    <main className="mx-auto max-w-3xl px-6 py-12">
      <Link href="/search" className="text-sm text-brand">
        ← Back to search
      </Link>

      <div className="mt-4 flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-semibold">{pg.name}</h1>
          <p className="mt-1 text-slate-600">
            {pg.address}, {pg.city}
            {pg.state ? `, ${pg.state}` : ''} {pg.pincode ?? ''}
          </p>
        </div>
        <span className="whitespace-nowrap rounded-full bg-slate-100 px-3 py-1 text-sm font-medium text-slate-600">
          {pg.genderPreference === 'CO_ED' ? 'Co-ed' : pg.genderPreference}
        </span>
      </div>

      {pg.description && <p className="mt-4 text-slate-700">{pg.description}</p>}

      <div className="mt-6 flex gap-6 rounded-lg border border-slate-200 p-4 text-sm">
        <LiveAvailabilityBadge pgId={pg.id} initialAvailableBeds={pg.availableBeds} initialTotalBeds={pg.totalBeds} />
        {pg.latitude !== null && pg.longitude !== null && (
          <div>
            <div className="text-slate-500">Location</div>
            <a
              className="text-brand"
              target="_blank"
              rel="noreferrer"
              href={`https://www.google.com/maps/search/?api=1&query=${pg.latitude},${pg.longitude}`}
            >
              View on map
            </a>
          </div>
        )}
      </div>

      <h2 className="mt-8 text-lg font-semibold">Rooms &amp; availability</h2>
      {pg.floors.length === 0 && <p className="mt-2 text-slate-500">No rooms have been set up yet.</p>}
      <div className="mt-4 space-y-6">
        {pg.floors.map((floor) => (
          <div key={floor.floorId}>
            <h3 className="font-medium text-slate-800">{floor.name}</h3>
            <div className="mt-2 grid gap-3 sm:grid-cols-2">
              {floor.rooms.map((room) => (
                <div key={room.roomId} className="rounded-md border border-slate-200 p-3 text-sm">
                  <div className="flex items-center justify-between">
                    <span className="font-medium">Room {room.roomNumber}</span>
                    <span className="text-xs text-slate-500">{room.roomType === 'AC' ? 'AC' : 'Non-AC'}</span>
                  </div>
                  <div className="mt-1 text-slate-600">
                    {room.sharingCount}-sharing • ₹{room.rentPerBed.toLocaleString('en-IN')}/bed/mo
                  </div>
                  <div className={`mt-1 ${room.availableBeds > 0 ? 'text-green-700' : 'text-slate-400'}`}>
                    {room.availableBeds > 0 ? `${room.availableBeds} bed(s) available` : 'Full'}
                  </div>
                  {room.availableBedOptions.length > 0 && (
                    <div className="mt-1 flex flex-wrap gap-1">
                      {room.availableBedOptions.map((bed) => (
                        <span key={bed.id} className="rounded bg-green-50 px-1.5 py-0.5 text-xs text-green-700">
                          {bed.label}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <p className="mt-10 rounded-md bg-slate-50 p-4 text-sm text-slate-500">
        Booking a specific bed is available in the PG Platform mobile app (sign in as a student, then book from a
        PG&apos;s details screen) -- see docs/decisions.md ADR-0018 for why booking shipped mobile-first. This web
        page doesn&apos;t have a student sign-in yet, so for now you can also contact the PG owner directly.
      </p>
    </main>
  );
}
