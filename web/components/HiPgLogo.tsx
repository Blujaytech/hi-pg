type HiPgLogoProps = {
  className?: string;
  inverse?: boolean;
};

/** Web rendering of the same house-bubble geometry used by Flutter. */
export function HiPgLogo({ className = '', inverse = false }: HiPgLogoProps) {
  return (
    <span
      className={`inline-flex items-center gap-2 ${className}`}
      aria-label="Hi PG"
    >
      <svg
        aria-hidden="true"
        viewBox="0 0 100 104"
        className="h-9 w-9 shrink-0 text-brand"
      >
        <path
          fill="currentColor"
          d="M40.5 12.9Q50 4 59.5 12.9L88.2 39.6Q94 45 94 53V74Q94 86 82 86H50Q45 86 40.6 88.4L23.6 97.6Q21 99 22.4 96.4L26.1 89.5Q28 86 24 86H17Q6 86 6 75V53Q6 45 11.8 39.6Z"
        />
        <rect x="70" y="12" width="11" height="23" rx="2.5" fill="currentColor" />
        <rect x="30.6" y="54.5" width="8.8" height="11" rx="4.4" fill="white" />
        <rect x="60.6" y="54.5" width="8.8" height="11" rx="4.4" fill="white" />
        <path d="M42 68.5Q50 77 58 68.5" fill="none" stroke="white" strokeWidth="5.4" strokeLinecap="round" />
      </svg>
      <span
        aria-hidden="true"
        className={`text-xl font-extrabold tracking-[-0.04em] ${inverse ? 'text-white' : 'text-ink'}`}
      >
        hi pg
      </span>
    </span>
  );
}
