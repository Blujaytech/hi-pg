/**
 * Thin fetch wrapper for the Spring Boot backend. Mirrors the shape of
 * mobile/lib/shared/api_client.dart's error handling (backend's ApiError:
 * { status, error, message, path, details }) so both clients surface the
 * same messages. See docs/api.md for the endpoint contracts.
 */

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080/api/v1';

export class ApiError extends Error {
  status?: number;
  details: string[];

  constructor(message: string, status?: number, details: string[] = []) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.details = details;
  }
}

type RequestOptions = {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  body?: unknown;
  accessToken?: string;
  cache?: RequestCache;
};

export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', body, accessToken, cache } = options;

  const response = await fetch(`${API_BASE_URL}${path}`, {
    method,
    cache,
    headers: {
      'Content-Type': 'application/json',
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    let message = `Request failed with status ${response.status}`;
    let details: string[] = [];
    try {
      const data = await response.json();
      message = data.message ?? message;
      details = data.details ?? [];
    } catch {
      // response body wasn't JSON -- keep the generic message
    }
    throw new ApiError(message, response.status, details);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}
