import { NextResponse } from 'next/server';
import { ApiError, apiFetch } from '@/lib/api';
import {
  clearOwnerSession,
  ownerSessionCookies,
  type AuthResponse,
  writeOwnerSession,
} from '@/lib/owner-session';

export async function GET() {
  const session = await ownerSessionCookies();
  return NextResponse.json({
    authenticated: Boolean(session.accessToken && session.refreshToken),
    fullName: session.fullName,
  });
}

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { email?: string; password?: string };
    if (!body.email?.trim() || !body.password) {
      return NextResponse.json({ message: 'Email and password are required.' }, { status: 400 });
    }

    const auth = await apiFetch<AuthResponse>('/auth/owner/login', {
      method: 'POST',
      body: { email: body.email.trim(), password: body.password },
      cache: 'no-store',
    });
    if (auth.role !== 'OWNER') {
      return NextResponse.json({ message: 'This workspace is available to PG owners only.' }, { status: 403 });
    }

    const response = NextResponse.json({ authenticated: true, fullName: auth.fullName });
    writeOwnerSession(response, auth);
    return response;
  } catch (error) {
    const status = error instanceof ApiError ? error.status ?? 500 : 500;
    const message = error instanceof ApiError ? error.message : 'Sign in is temporarily unavailable.';
    return NextResponse.json({ message }, { status });
  }
}

export async function DELETE() {
  const session = await ownerSessionCookies();
  if (session.refreshToken) {
    try {
      await apiFetch('/auth/logout', {
        method: 'POST',
        body: { refreshToken: session.refreshToken },
        cache: 'no-store',
      });
    } catch {
      // Local sign-out must still complete when the backend session has expired.
    }
  }
  const response = NextResponse.json({ authenticated: false });
  clearOwnerSession(response);
  return response;
}

