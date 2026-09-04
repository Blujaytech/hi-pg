/**
 * Types + fetchers for the public (unauthenticated) discovery endpoints
 * under `/public/pgs` -- technical plan §6 Phase 9. See docs/api.md for the
 * backend contract these mirror.
 */
import { apiFetch } from './api';

export type GenderPreference = 'MALE' | 'FEMALE' | 'CO_ED';

export interface PgSearchResult {
  id: string;
  name: string;
  city: string;
  address: string;
  description: string | null;
  genderPreference: GenderPreference;
  latitude: number | null;
  longitude: number | null;
  availableBeds: number;
  minRentPerBed: number | null;
  maxRentPerBed: number | null;
}

export interface PagedResponse<T> {
  content: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}

export interface AvailableBedOption {
  id: string;
  label: string;
}

export interface RoomAvailability {
  roomId: string;
  roomNumber: string;
  roomType: 'AC' | 'NON_AC';
  sharingCount: number;
  rentPerBed: number;
  availableBeds: number;
  availableBedOptions: AvailableBedOption[];
}

export interface FloorAvailability {
  floorId: string;
  name: string;
  floorNumber: number;
  rooms: RoomAvailability[];
}

export interface PgDetails {
  id: string;
  name: string;
  address: string;
  city: string;
  state: string | null;
  pincode: string | null;
  description: string | null;
  genderPreference: GenderPreference;
  latitude: number | null;
  longitude: number | null;
  totalBeds: number;
  availableBeds: number;
  floors: FloorAvailability[];
}

export interface SearchFilters {
  city?: string;
  genderPreference?: GenderPreference;
  minRent?: string;
  maxRent?: string;
  page?: number;
}

export async function searchPgs(filters: SearchFilters): Promise<PagedResponse<PgSearchResult>> {
  const params = new URLSearchParams();
  if (filters.city) params.set('city', filters.city);
  if (filters.genderPreference) params.set('genderPreference', filters.genderPreference);
  if (filters.minRent) params.set('minRent', filters.minRent);
  if (filters.maxRent) params.set('maxRent', filters.maxRent);
  params.set('page', String(filters.page ?? 0));
  params.set('size', '12');

  return apiFetch<PagedResponse<PgSearchResult>>(`/public/pgs?${params.toString()}`, { cache: 'no-store' });
}

export async function getPgDetails(pgId: string): Promise<PgDetails> {
  return apiFetch<PgDetails>(`/public/pgs/${pgId}`, { cache: 'no-store' });
}
