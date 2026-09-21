'use client';

import { useState } from 'react';
import { ApiError, apiFetch } from '../../../lib/api';

type KycDocument = { id: string; type: string; fileName: string; contentType: string; sizeBytes: number };
type KycSubmission = {
  id: string;
  pgId: string;
  pgName: string;
  ownerName: string;
  verifiedPhone: string;
  legalName: string;
  panLastFour: string;
  aadhaarLastFour: string;
  status: string;
  submittedAt: string;
  documents: KycDocument[];
};

type ReviewDraft = { linkedAccountId: string; commissionPercent: string; reviewNote: string };

export default function AdminOnboardingPage() {
  const [token, setToken] = useState('');
  const [submissions, setSubmissions] = useState<KycSubmission[]>([]);
  const [drafts, setDrafts] = useState<Record<string, ReviewDraft>>({});
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  async function loadPending() {
    setBusy(true);
    setMessage('');
    try {
      const rows = await apiFetch<KycSubmission[]>('/admin/kyc/pending', { accessToken: token, cache: 'no-store' });
      setSubmissions(rows);
      setDrafts(Object.fromEntries(rows.map(row => [row.id, drafts[row.id] ?? {
        linkedAccountId: '', commissionPercent: '0', reviewNote: '',
      }])));
    } catch (error) {
      setMessage(error instanceof ApiError ? error.message : 'Could not load KYC submissions.');
    } finally {
      setBusy(false);
    }
  }

  function updateDraft(id: string, patch: Partial<ReviewDraft>) {
    setDrafts(current => ({ ...current, [id]: { ...current[id], ...patch } }));
  }

  async function review(row: KycSubmission, status: 'VERIFIED' | 'REJECTED') {
    const draft = drafts[row.id];
    setBusy(true);
    setMessage('');
    try {
      await apiFetch(`/admin/kyc/${row.id}`, {
        method: 'PATCH', accessToken: token,
        body: {
          status,
          razorpayLinkedAccountId: status === 'VERIFIED' ? draft.linkedAccountId.trim() : null,
          platformCommissionBps: Math.round(Number(draft.commissionPercent || 0) * 100),
          reviewNote: draft.reviewNote.trim() || null,
        },
      });
      setSubmissions(current => current.filter(item => item.id !== row.id));
      setMessage(status === 'VERIFIED' ? 'KYC verified and Razorpay payments enabled.' : 'KYC returned to the owner.');
    } catch (error) {
      setMessage(error instanceof ApiError ? error.message : 'Review could not be saved.');
    } finally {
      setBusy(false);
    }
  }

  async function openDocument(documentId: string) {
    try {
      const result = await apiFetch<{ url: string }>(`/admin/kyc/documents/${documentId}/download-url`, {
        accessToken: token, cache: 'no-store',
      });
      window.open(result.url, '_blank', 'noopener,noreferrer');
    } catch (error) {
      setMessage(error instanceof ApiError ? error.message : 'Document could not be opened.');
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-6xl bg-slate-50 px-5 py-10">
      <div className="mb-8 flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <p className="text-sm font-semibold uppercase tracking-widest text-indigo-600">Hi PG administration</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-950">Owner KYC & payment onboarding</h1>
          <p className="mt-2 text-slate-600">Verify mobile, identity documents, property photos, and the Razorpay Route account before enabling collections.</p>
        </div>
        <div className="flex w-full max-w-xl gap-2">
          <input type="password" value={token} onChange={event => setToken(event.target.value)}
            placeholder="Admin access token" className="min-w-0 flex-1 rounded-xl border border-slate-300 bg-white px-4 py-3" />
          <button onClick={loadPending} disabled={busy || !token}
            className="rounded-xl bg-slate-950 px-5 py-3 font-semibold text-white disabled:opacity-50">
            {busy ? 'Loading…' : 'Load queue'}
          </button>
        </div>
      </div>

      {message && <div className="mb-5 rounded-xl border border-indigo-100 bg-indigo-50 px-4 py-3 text-sm text-indigo-900">{message}</div>}
      {!busy && submissions.length === 0 && (
        <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-12 text-center text-slate-500">
          Enter an admin token to load the queue, or there are no pending submissions.
        </div>
      )}

      <div className="grid gap-5">
        {submissions.map(row => {
          const draft = drafts[row.id] ?? { linkedAccountId: '', commissionPercent: '0', reviewNote: '' };
          return (
            <section key={row.id} className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="grid gap-5 lg:grid-cols-[1fr_1fr]">
                <div>
                  <h2 className="text-xl font-bold text-slate-950">{row.pgName}</h2>
                  <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
                    <div><dt className="text-slate-500">Owner</dt><dd className="font-semibold">{row.ownerName}</dd></div>
                    <div><dt className="text-slate-500">Verified mobile</dt><dd className="font-semibold">{row.verifiedPhone}</dd></div>
                    <div><dt className="text-slate-500">Legal name</dt><dd className="font-semibold">{row.legalName}</dd></div>
                    <div><dt className="text-slate-500">Submitted</dt><dd className="font-semibold">{new Date(row.submittedAt).toLocaleString()}</dd></div>
                    <div><dt className="text-slate-500">PAN</dt><dd className="font-semibold">••••••{row.panLastFour}</dd></div>
                    <div><dt className="text-slate-500">Aadhaar</dt><dd className="font-semibold">•••• •••• {row.aadhaarLastFour}</dd></div>
                  </dl>
                  <div className="mt-5 flex flex-wrap gap-2">
                    {row.documents.map(document => (
                      <button key={document.id} onClick={() => openDocument(document.id)}
                        className="rounded-full border border-slate-300 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-50">
                        {document.type.replaceAll('_', ' ')}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="grid gap-3">
                  <label className="text-sm font-medium">Razorpay linked account ID
                    <input value={draft.linkedAccountId} onChange={event => updateDraft(row.id, { linkedAccountId: event.target.value })}
                      placeholder="acc_…" className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5" />
                  </label>
                  <label className="text-sm font-medium">Platform commission (%)
                    <input type="number" min="0" max="100" step="0.01" value={draft.commissionPercent}
                      onChange={event => updateDraft(row.id, { commissionPercent: event.target.value })}
                      className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5" />
                  </label>
                  <label className="text-sm font-medium">Review note
                    <textarea value={draft.reviewNote} onChange={event => updateDraft(row.id, { reviewNote: event.target.value })}
                      rows={2} className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5" />
                  </label>
                  <div className="mt-2 flex gap-2">
                    <button disabled={busy || !draft.linkedAccountId.trim()} onClick={() => review(row, 'VERIFIED')}
                      className="flex-1 rounded-xl bg-emerald-600 px-4 py-3 font-semibold text-white disabled:opacity-50">Verify & enable</button>
                    <button disabled={busy} onClick={() => review(row, 'REJECTED')}
                      className="rounded-xl border border-rose-300 px-4 py-3 font-semibold text-rose-700 disabled:opacity-50">Reject</button>
                  </div>
                </div>
              </div>
            </section>
          );
        })}
      </div>
    </main>
  );
}
