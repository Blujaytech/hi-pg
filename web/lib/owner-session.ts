import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { ApiError, apiFetch } from '@/lib/api';

const ACCESS_COOKIE = 'hipg_owner_access';
const REFRESH_COOKIE = 'hipg_owner_refresh';
const NAME_COOKIE = 'hipg_owner_name';

export type AuthResponse = {
  accessToken: string;
  refreshToken: string;
  userId: string;
  fullName: string;
  role: 'OWNER' | 'STUDENT' | 'ADMIN';
};

const secure = process.env.NODE_ENV === 'production';

export function writeOwnerSession(response: NextResponse, auth: AuthResponse) {
  const common = { httpOnly: true, secure, sameSite: 'lax' as const, path: '/' };
  response.cookies.set(ACCESS_COOKIE, auth.accessToken, { ...common, maxAge: 15 * 60 });
  response.cookies.set(REFRESH_COOKIE, auth.refreshToken, { ...common, maxAge: 30 * 24 * 60 * 60 });
  response.cookies.set(NAME_COOKIE, auth.fullName, { ...common, maxAge: 30 * 24 * 60 * 60 });
}

export function clearOwnerSession(response: NextResponse) {
  const expired = { httpOnly: true, secure, sameSite: 'lax' as const, path: '/', maxAge: 0 };
  response.cookies.set(ACCESS_COOKIE, '', expired);
  response.cookies.set(REFRESH_COOKIE, '', expired);
  response.cookies.set(NAME_COOKIE, '', expired);
}

export async function ownerSessionCookies() {
  const store = await cookies();
  return {
    accessToken: store.get(ACCESS_COOKIE)?.value,
    refreshToken: store.get(REFRESH_COOKIE)?.value,
    fullName: store.get(NAME_COOKIE)?.value,
  };
}

export async function refreshOwnerSession(refreshToken: string) {
  const auth = await apiFetch<AuthResponse>('/auth/refresh', {
    method: 'POST',
    body: { refreshToken },
    cache: 'no-store',
  });
  if (auth.role !== 'OWNER') {
    throw new ApiError('This workspace is available to PG owners only.', 403);
  }
  return auth;
}

