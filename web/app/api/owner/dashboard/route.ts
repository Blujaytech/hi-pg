import { NextResponse } from 'next/server';
import { ApiError, apiFetch } from '@/lib/api';
import type { DashboardSummary } from '@/lib/owner-dashboard';
import {
  clearOwnerSession,
  ownerSessionCookies,
  refreshOwnerSession,
  writeOwnerSession,
} from '@/lib/owner-session';

export async function GET() {
  const session = await ownerSessionCookies();
  if (!session.accessToken || !session.refreshToken) {
    return NextResponse.json({ message: 'Owner sign-in is required.' }, { status: 401 });
  }

  try {
    const summary = await loadDashboard(session.accessToken);
    return NextResponse.json(summary);
  } catch (error) {
    if (!(error instanceof ApiError) || error.status !== 401) {
      return apiErrorResponse(error);
    }
  }

  try {
    const auth = await refreshOwnerSession(session.refreshToken);
    const summary = await loadDashboard(auth.accessToken);
    const response = NextResponse.json(summary);
    writeOwnerSession(response, auth);
    return response;
  } catch (error) {
    const response = apiErrorResponse(error);
    if (response.status === 401 || response.status === 403) clearOwnerSession(response);
    return response;
  }
}

function loadDashboard(accessToken: string) {
  return apiFetch<DashboardSummary>('/owner/dashboard', {
    accessToken,
    cache: 'no-store',
  });
}

function apiErrorResponse(error: unknown) {
  const status = error instanceof ApiError ? error.status ?? 500 : 500;
  const message = error instanceof ApiError ? error.message : 'Dashboard data is temporarily unavailable.';
  return NextResponse.json({ message }, { status });
}

