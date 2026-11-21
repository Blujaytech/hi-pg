import Link from 'next/link';
import { notFound } from 'next/navigation';
import { LiveAvailabilityBadge } from '@/components/LiveAvailabilityBadge';
import { MotionPage } from '@/components/MotionPrimitives';
import { ApiError } from '@/lib/api';
import { getPgDetails, type GenderPreference, type PgDetails } from '@/lib/discovery';

export const dynamic = 'force-dynamic';

export default async function PgDetailsPage({ params }: { params: Promise<{ pgId: string }> }) {
  const { pgId } = await params;
  let pg;
  try {
    pg = await getPgDetails(pgId);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }

  const photos = Array.from(new Set([pg.photoUrl, ...(pg.photos ?? []).map((photo) => photo.url)].filter(Boolean))) as string[];
  const mapHref = propertyMapHref(pg);
  const monthlyRents = pg.floors.flatMap((floor) => floor.rooms.map((room) => room.rentPerBed)).filter((rent) => rent > 0);
  const minimumMonthlyRent = monthlyRents.length > 0 ? Math.min(...monthlyRents) : null;

  return (
    <MotionPage>
    <main className="property-details-page">
      <Link href="/search" className="property-back-link">
        <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="m15 18-6-6 6-6" /></svg>
        Back to search
      </Link>

      <section className="property-details-hero">
        <PropertyMedia name={pg.name} photos={photos} />
        <div className="property-title-block">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <span className={`rounded-full px-3 py-1 text-xs font-extrabold ${pg.verified ? 'bg-emerald-50 text-success' : 'bg-amber-50 text-warning'}`}>
                  {pg.verified ? 'Verified property' : 'Verification pending'}
                </span>
                <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold text-slate-600">
                  {genderLabel(pg.genderPreference)}
                </span>
              </div>
              <h1>{pg.name}</h1>
              <p className="property-address">
                {[pg.address, pg.city, pg.state, pg.pincode].filter(Boolean).join(', ')}
              </p>
              <div className="property-summary-facts">
                <span>{pg.totalBeds} total beds</span>
                <span>{pg.availableBeds} available now</span>
                <span>{pg.floors.length} {pg.floors.length === 1 ? 'floor' : 'floors'}</span>
              </div>
            </div>
            {minimumMonthlyRent !== null && (
              <div className="rounded-card bg-brand-soft px-4 py-3 sm:text-right">
                <p className="text-xs font-bold text-brand-text">Rooms from</p>
                <p className="mt-1 text-xl font-extrabold text-ink">
                  {formatRupees(minimumMonthlyRent)}<span className="text-xs font-semibold text-slate-500"> / month</span>
                </p>
              </div>
            )}
          </div>
        </div>
      </section>

      <div className="property-details-content">
        <div className="space-y-7">
          {pg.description && (
            <section className="rounded-panel border border-line bg-white p-5 shadow-card sm:p-6">
              <h2 className="text-xl font-extrabold text-ink">About this property</h2>
              <p className="mt-3 whitespace-pre-line text-sm leading-7 text-slate-600">{pg.description}</p>
            </section>
          )}

          <section className="rounded-panel border border-line bg-white p-5 shadow-card sm:p-6">
            <div className="flex flex-wrap items-end justify-between gap-3">
              <div>
                <h2 className="text-xl font-extrabold text-ink">Rooms &amp; bed availability</h2>
                <p className="mt-1 text-sm text-slate-500">Review each configured room before booking in the mobile app.</p>
              </div>
              <span className="text-xs font-bold text-slate-500">
                {pg.floors.length} {pg.floors.length === 1 ? 'floor / block' : 'floors / blocks'}
              </span>
            </div>

            {!pg.verified || !pg.bookingEnabled ? (
              <div className="mt-5 rounded-card border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-900">
                Rooms, beds, online booking, and payments remain unavailable until owner KYC and property approval are complete.
              </div>
            ) : pg.floors.length === 0 ? (
              <p className="mt-5 rounded-card bg-slate-50 p-5 text-sm text-slate-500">No rooms have been configured yet.</p>
            ) : (
              <div className="mt-5 space-y-5">
                {pg.floors.map((floor) => (
                  <section key={floor.floorId}>
                    <h3 className="text-sm font-extrabold uppercase tracking-wide text-slate-500">{floor.name}</h3>
                    <div className="mt-3 grid gap-3 sm:grid-cols-2">
                      {floor.rooms.map((room) => (
                        <article key={room.roomId} className="property-room-card">
                          <div className="flex items-start justify-between gap-3">
                            <div>
                              <h4 className="font-extrabold text-ink">Room {room.roomNumber}</h4>
                              <p className="mt-1 text-xs font-semibold text-slate-500">
                                {room.sharingCount}-sharing · {room.roomType === 'AC' ? 'AC' : 'Non-AC'}
                              </p>
                            </div>
                            <span className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${room.availableBeds > 0 ? 'bg-emerald-50 text-success' : 'bg-slate-100 text-slate-500'}`}>
                              {room.availableBeds > 0 ? `${room.availableBeds} free` : 'Full'}
                            </span>
                          </div>
                          <p className="mt-4 text-base font-extrabold text-ink">
                            {formatRupees(room.rentPerBed)}<span className="text-xs font-semibold text-slate-500"> / bed / month</span>
                          </p>
                          {room.dayWiseRate != null && room.bookingMode !== 'MONTHLY' && (
                            <p className="mt-1 text-xs font-semibold text-slate-500">
                              {formatRupees(room.dayWiseRate)} / day
                            </p>
                          )}
                          {room.availableBedOptions.length > 0 && (
                            <div className="mt-4 flex flex-wrap gap-2" aria-label="Available beds">
                              {room.availableBedOptions.map((bed) => (
                                <span key={bed.id} className="rounded-md border border-emerald-200 bg-emerald-50 px-2 py-1 text-xs font-bold text-success">
                                  {bed.label}
                                </span>
                              ))}
                            </div>
                          )}
                        </article>
                      ))}
                    </div>
                  </section>
                ))}
              </div>
            )}
          </section>
        </div>

        <aside className="property-booking-aside">
          <div className="property-booking-card">
            {minimumMonthlyRent !== null && (
              <div className="booking-price">
                <span>Rooms from</span>
                <strong>{formatRupees(minimumMonthlyRent)} <small>/ month</small></strong>
              </div>
            )}
            <h2>Current availability</h2>
            <div className="mt-4 rounded-card bg-slate-50 p-4">
              <LiveAvailabilityBadge pgId={pg.id} initialAvailableBeds={pg.availableBeds} initialTotalBeds={pg.totalBeds} />
            </div>
            {mapHref && (
              <a
                href={mapHref}
                target="_blank"
                rel="noreferrer"
                className="mt-4 inline-flex min-h-12 w-full items-center justify-center rounded-card border border-line px-4 text-sm font-bold text-ink transition hover:border-brand hover:text-brand-text"
              >
                Open in Google Maps
              </a>
            )}
            <a href="https://hipg-website.pages.dev" target="_blank" rel="noreferrer" className="property-booking-cta">
              Choose a bed in the app
            </a>
            <p className="booking-protection-note">
              Bed availability and payment confirmation are verified by Hi PG before a booking is completed.
            </p>
          </div>

          <div className="rounded-panel bg-ink p-5 text-white shadow-card">
            <p className="text-xs font-extrabold uppercase tracking-[0.14em] text-white/65">Specific-bed booking</p>
            <h2 className="mt-2 text-lg font-extrabold">Choose and book in the Hi PG app</h2>
            <p className="mt-2 text-sm leading-6 text-white/75">
              Sign in on mobile to select an available bed, confirm dates, and continue through the protected payment flow.
            </p>
          </div>
        </aside>
      </div>
    </main>
    </MotionPage>
  );
}

function PropertyMedia({ name, photos }: { name: string; photos: string[] }) {
  if (photos.length === 0) {
    return <div className="property-placeholder property-gallery-empty" role="img" aria-label={`${name} photo placeholder`} />;
  }

  return (
    <div className="property-gallery" aria-label={`${name} property photos`}>
      {Array.from({ length: Math.min(5, Math.max(1, photos.length)) }, (_, index) => (
        <div
          key={`${photos[index] ?? photos[0]}-${index}`}
          className={`property-gallery-image property-gallery-image-${index + 1}`}
          style={{ backgroundImage: `url(${JSON.stringify(photos[index] ?? photos[0])})` }}
          role="img"
          aria-label={`${name} photo ${index + 1}`}
        />
      ))}
      <span className="property-photo-count">{photos.length} {photos.length === 1 ? 'photo' : 'photos'}</span>
    </div>
  );
}

function propertyMapHref(pg: PgDetails) {
  if (pg.locationUrl?.startsWith('https://')) return pg.locationUrl;
  if (pg.latitude !== null && pg.longitude !== null) {
    return `https://www.google.com/maps/search/?api=1&query=${pg.latitude},${pg.longitude}`;
  }
  return null;
}

function genderLabel(gender: GenderPreference) {
  if (gender === 'MALE') return 'Men';
  if (gender === 'FEMALE') return 'Women';
  if (gender === 'CO_ED') return 'Co-living';
  return 'All residents';
}

function formatRupees(value: number) {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
}
