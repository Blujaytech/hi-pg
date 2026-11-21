'use client';

import { useEffect, useRef, useState } from 'react';
import { AnimatePresence, motion, useReducedMotion } from 'motion/react';
import type { GenderPreference } from '@/lib/discovery';

export type SearchFilterDefaults = {
  city?: string;
  genderPreference?: GenderPreference;
  minRent?: string;
  maxRent?: string;
};

export function SearchFiltersPanel({ defaults }: { defaults: SearchFilterDefaults }) {
  const [open, setOpen] = useState(false);
  const reducedMotion = useReducedMotion();
  const triggerRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const dialog = dialogRef.current;
    const focusableSelector =
      'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        setOpen(false);
        return;
      }
      if (event.key !== 'Tab' || !dialog) return;
      const focusable = Array.from(dialog.querySelectorAll<HTMLElement>(focusableSelector));
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    document.addEventListener('keydown', onKeyDown);
    dialog?.querySelector<HTMLElement>('[data-filter-close]')?.focus();
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      document.body.style.overflow = previousOverflow;
      previouslyFocused?.focus();
    };
  }, [open]);

  return (
    <>
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen(true)}
        className="inline-flex min-h-11 items-center gap-2 rounded-full border border-line bg-white px-4 text-sm font-bold text-ink shadow-card transition hover:border-brand"
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-controls="mobile-search-filters"
      >
        <FilterIcon />
        Filters
        {activeFilterCount(defaults) > 0 && (
          <span className="rounded-full bg-brand px-2 py-0.5 text-xs text-white">{activeFilterCount(defaults)}</span>
        )}
      </button>

      <AnimatePresence>
        {open && (
        <motion.div
          className="filter-overlay fixed inset-0 z-[70]"
          initial={reducedMotion ? false : { opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: reducedMotion ? 0 : 0.18 }}
        >
          <motion.button
            type="button"
            className="absolute inset-0 bg-ink/55"
            aria-label="Close filters"
            onClick={() => setOpen(false)}
            initial={false}
          />
          <motion.div
            ref={dialogRef}
            id="mobile-search-filters"
            role="dialog"
            aria-modal="true"
            aria-labelledby="mobile-search-filter-title"
            className="filter-dialog"
            initial={reducedMotion ? false : { opacity: 0, y: 28, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 20, scale: 0.98 }}
            transition={{ duration: reducedMotion ? 0 : 0.26, ease: [0.2, 0.8, 0.2, 1] }}
          >
            <div className="filter-dialog-handle" />
            <FilterForm
              defaults={defaults}
              onClose={() => setOpen(false)}
              titleId="mobile-search-filter-title"
            />
          </motion.div>
        </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}

function FilterForm({
  defaults,
  onClose,
  titleId,
}: {
  defaults: SearchFilterDefaults;
  onClose?: () => void;
  titleId?: string;
}) {
  return (
    <form action="/search" method="get">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h2 id={titleId} className="text-lg font-extrabold text-ink">Filter stays</h2>
          <p className="mt-1 text-xs text-slate-500">Use only the details that matter to you.</p>
        </div>
        {onClose && (
          <button
            type="button"
            onClick={onClose}
            data-filter-close
            className="grid h-11 w-11 place-items-center rounded-full text-xl text-slate-600 hover:bg-slate-100"
            aria-label="Close filters"
          >
            ×
          </button>
        )}
      </div>

      <label className="mt-6 block text-sm font-bold text-ink" htmlFor={onClose ? 'mobile-city' : 'desktop-city'}>
        City
      </label>
      <input
        id={onClose ? 'mobile-city' : 'desktop-city'}
        type="text"
        name="city"
        placeholder="Hyderabad"
        defaultValue={defaults.city ?? ''}
        className="mt-2 min-h-12 w-full rounded-card border border-line bg-white px-3 text-sm outline-none transition focus:border-brand"
      />

      <label className="mt-5 block text-sm font-bold text-ink" htmlFor={onClose ? 'mobile-gender' : 'desktop-gender'}>
        PG category
      </label>
      <select
        id={onClose ? 'mobile-gender' : 'desktop-gender'}
        name="genderPreference"
        defaultValue={defaults.genderPreference ?? ''}
        className="mt-2 min-h-12 w-full rounded-card border border-line bg-white px-3 text-sm outline-none transition focus:border-brand"
      >
        <option value="">All categories</option>
        <option value="MALE">Men</option>
        <option value="FEMALE">Women</option>
        <option value="CO_ED">Co-living</option>
      </select>

      <fieldset className="mt-5">
        <legend className="text-sm font-bold text-ink">Monthly budget</legend>
        <div className="mt-2 grid grid-cols-2 gap-2">
          <input
            type="number"
            name="minRent"
            min="0"
            placeholder="Minimum"
            aria-label="Minimum monthly rent"
            defaultValue={defaults.minRent ?? ''}
            className="min-h-12 min-w-0 rounded-card border border-line bg-white px-3 text-sm outline-none transition focus:border-brand"
          />
          <input
            type="number"
            name="maxRent"
            min="0"
            placeholder="Maximum"
            aria-label="Maximum monthly rent"
            defaultValue={defaults.maxRent ?? ''}
            className="min-h-12 min-w-0 rounded-card border border-line bg-white px-3 text-sm outline-none transition focus:border-brand"
          />
        </div>
      </fieldset>

      <button type="submit" className="mt-6 min-h-12 w-full rounded-card bg-brand px-5 text-sm font-extrabold text-white transition hover:bg-brand-pressed">
        Show matching PGs
      </button>
      {activeFilterCount(defaults) > 0 && (
        <a href="/search" className="mt-2 inline-flex min-h-11 w-full items-center justify-center text-sm font-bold text-brand-text">
          Clear filters
        </a>
      )}
    </form>
  );
}

function activeFilterCount(defaults: SearchFilterDefaults) {
  return [defaults.city, defaults.genderPreference, defaults.minRent, defaults.maxRent].filter(Boolean).length;
}

function FilterIcon() {
  return (
    <svg aria-hidden="true" viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M4 7h16M7 12h10M10 17h4" />
    </svg>
  );
}
