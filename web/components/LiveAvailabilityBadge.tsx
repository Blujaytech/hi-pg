'use client';

import { useEffect, useState } from 'react';
import { API_BASE_URL } from '@/lib/api';

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
    const source = new EventSource(`${API_BASE_URL}/public/pgs/${pgId}/availability/stream`);

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
    <div className="flex items-end justify-between gap-3">
      <div>
        <div className="text-xs font-bold text-slate-500">
          Available now {live && <span className="text-success">• live</span>}
        </div>
        <div className={`mt-1 text-2xl font-extrabold ${available > 0 ? 'text-success' : 'text-slate-400'}`}>
          {available} <span className="text-sm font-semibold text-slate-500">of {total} beds</span>
        </div>
      </div>
      <span className={`h-3 w-3 rounded-full ${available > 0 ? 'bg-emerald-400' : 'bg-slate-300'}`} aria-hidden="true" />
    </div>
  );
}
