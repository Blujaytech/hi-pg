'use client';

import { useEffect, useState } from 'react';

/**
 * Phase 10 -- subscribes to the backend's SSE stream for one PG and shows
 * a live-updating bed count. Renders the server-fetched initial numbers
 * immediately (no flash of empty state), then swaps to whatever the stream
 * reports from its first event onward -- including the connection's own
 * initial snapshot, so a bed that changed between the page's server-side
 * fetch and this component mounting is still caught.
 */
export function LiveAvailabilityBadge({
  pgId,
  initialAvailableBeds,
  initialTotalBeds,
}: {
  pgId: string;
  initialAvailableBeds: number;
  initialTotalBeds: number;
}) {
  const [available, setAvailable] = useState(initialAvailableBeds);
  const [total, setTotal] = useState(initialTotalBeds);
  const [live, setLive] = useState(false);

  useEffect(() => {
    const apiBase = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080/api/v1';
    const source = new EventSource(`${apiBase}/public/pgs/${pgId}/availability/stream`);

    source.addEventListener('availability', (event) => {
      try {
        const data = JSON.parse((event as MessageEvent).data) as { availableBeds: number; totalBeds: number };
        setAvailable(data.availableBeds);
        setTotal(data.totalBeds);
        setLive(true);
      } catch {
        // ignore a malformed event rather than breaking the page
      }
    });

    source.onerror = () => setLive(false);

    return () => source.close();
  }, [pgId]);

  return (
    <div>
      <div className="text-slate-500">
        Available now {live && <span className="text-green-600">• live</span>}
      </div>
      <div className={`text-lg font-semibold ${available > 0 ? 'text-green-700' : 'text-slate-400'}`}>
        {available} / {total}
      </div>
    </div>
  );
}
