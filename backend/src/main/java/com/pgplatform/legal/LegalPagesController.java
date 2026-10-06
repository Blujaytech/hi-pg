package com.pgplatform.legal;

import com.pgplatform.auth.AccountDeletionService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

@RestController
public class LegalPagesController {
    private static final String EFFECTIVE_DATE = "2 October 2026";
    private final LegalProperties properties;

    public LegalPagesController(LegalProperties properties) {
        this.properties = properties;
    }

    @GetMapping(value = "/privacy", produces = MediaType.TEXT_HTML_VALUE)
    public String privacy() {
        String operator = value(properties.operatorName(), "Hi PG");
        String email = value(properties.supportEmail(), "Use Help & Support inside the Hi PG app");
        String address = value(properties.postalAddress(), "Available from the operator on request");
        return page("Privacy Policy", """
                <p class="lead">This Privacy Policy explains how %s operates Hi PG and handles personal data.</p>
                <h2>Who we are</h2>
                <p>Operator: <strong>%s</strong><br>Privacy contact: <a href="mailto:%s">%s</a><br>Postal address: %s</p>
                <h2>Data we process</h2>
                <ul>
                  <li>Account details such as name, email, verified mobile number, role and session identifiers.</li>
                  <li>Customer profile, address, occupation, guardian/contact details, profile photo and consent records.</li>
                  <li>Owner, property and KYC information, including private identity/property documents.</li>
                  <li>Property location, photos, facilities, rooms, beds, pricing and availability.</li>
                  <li>Bookings, stays, fees, deposits, receipts, complaints and support requests.</li>
                  <li>Payment status and gateway/reference identifiers. Hi PG does not store card, bank-login or UPI PIN credentials.</li>
                  <li>Foreground location when a user chooses nearby discovery. Manual location search remains available.</li>
                  <li>Device push token, security logs, IP/rate-limit information and diagnostic request identifiers.</li>
                </ul>
                <h2>Why we use data</h2>
                <p>We use data to authenticate accounts, provide discovery and booking, operate properties, process and reconcile payments, prevent duplicate/fraudulent activity, deliver notifications, resolve complaints, provide support, meet legal obligations and protect users.</p>
                <h2>Service providers and disclosures</h2>
                <p>Depending on the enabled production configuration, data may be processed by our hosting/database provider, private S3-compatible object storage, Firebase and Google Identity, Google Maps Platform, Razorpay, and configured notification providers. Property/customer data is shared with the relevant owner or customer only as needed to deliver the booked accommodation. We do not sell personal data.</p>
                <h2>Identity documents</h2>
                <p>Identity and KYC documents are stored in a private bucket. Access is authorized by the backend and provided through short-lived signed URLs. Aadhaar is voluntary, alternatives are supported, and Aadhaar data is not used for advertising.</p>
                <h2>Retention and deletion</h2>
                <p>Profile data and private files are removed or irreversibly anonymized when an account is deleted. Limited booking, payment, receipt, tax, fraud-prevention and legal-acceptance records may be retained for applicable legal, accounting, dispute and security periods. Retained records are disconnected from login identifiers and are not used to recreate the account.</p>
                <p>Users can delete an account from <strong>Account → Delete account</strong>. Users who cannot sign in can use the <a href="/account-deletion">account-deletion page</a>.</p>
                <h2>Security</h2>
                <p>Production traffic uses HTTPS. Tokens are stored in platform secure storage, access is role/ownership checked by the server, sensitive buckets are private, and privileged document/payment access is logged. No system can guarantee absolute security.</p>
                <h2>Your choices</h2>
                <p>You may deny location and use manual search, deny notifications, correct profile data, withdraw optional permissions, or request account deletion. Contact the privacy address above for access, correction, deletion or grievance questions.</p>
                <h2>Children</h2>
                <p>Hi PG is intended for adults aged 18 and over and is not designed for children.</p>
                <h2>Changes</h2>
                <p>Material changes will be identified by a new policy version/effective date and, where required, presented for renewed acceptance.</p>
                """.formatted(operator, operator, escapeAttribute(email), email, address));
    }

    @GetMapping(value = "/terms", produces = MediaType.TEXT_HTML_VALUE)
    public String terms() {
        String operator = value(properties.operatorName(), "Hi PG");
        String email = value(properties.supportEmail(), "Use Help & Support inside the Hi PG app");
        return page("Terms of Service", """
                <p class="lead">These terms govern use of Hi PG, operated by %s.</p>
                <h2>Eligibility and accounts</h2>
                <p>You must be at least 18, provide accurate information, protect your credentials and use only accounts you are authorized to control.</p>
                <h2>Marketplace role</h2>
                <p>Hi PG provides discovery, booking, property-management and payment-support technology. Accommodation is supplied by the relevant PG owner. Listing details, house rules, deposits, notice periods, cancellation terms and availability shown at checkout form part of the booking information.</p>
                <h2>Bookings and payments</h2>
                <p>A booking is confirmed only after the server records the required payment/owner approval and confirms bed availability. Razorpay payments are gateway verified. Direct UPI/cash payments are owner-confirmed and are not held or independently verified by Hi PG. Never pay a destination not shown in the authenticated booking flow.</p>
                <h2>Cancellations, refunds and deposits</h2>
                <p>Cancellation, refund, notice-period and deposit-deduction outcomes depend on the booking terms and payment channel. An account-deletion request does not cancel an active stay, erase a payment obligation, or replace a refund/dispute request.</p>
                <h2>Owner obligations</h2>
                <p>Owners must have authority to list and operate a property, keep inventory/prices accurate, protect customer data, comply with applicable accommodation, tax and safety rules, and provide truthful KYC/payment details.</p>
                <h2>Acceptable use</h2>
                <p>Do not impersonate another person, upload unlawful content, misuse identity documents, evade payment, manipulate availability, attack the service, or use data outside the accommodation/support purpose.</p>
                <h2>Availability and liability</h2>
                <p>The service may be interrupted for maintenance, security or provider failures. Nothing in these terms excludes rights or liabilities that cannot legally be excluded.</p>
                <h2>Support</h2>
                <p>Contact <a href="mailto:%s">%s</a> or use Help & Support in the app for account, booking, payment or grievance assistance.</p>
                """.formatted(operator, escapeAttribute(email), email));
    }

    @GetMapping(value = "/account-deletion", produces = MediaType.TEXT_HTML_VALUE)
    public String accountDeletion() {
        String email = value(properties.supportEmail(), "");
        String contact = email.isBlank()
                ? "<p>If you cannot sign in, use the developer contact shown on the Hi PG Google Play listing.</p>"
                : "<p>If you cannot sign in, email <a href=\"mailto:" + escapeAttribute(email)
                    + "?subject=Hi%20PG%20account%20deletion\">" + email + "</a> from your registered address or include your registered mobile number. We will verify ownership before acting.</p>";
        return page("Delete your Hi PG account", """
                <p class="lead">You can permanently delete a customer or owner account from inside Hi PG.</p>
                <h2>Delete inside the app</h2>
                <ol>
                  <li>Sign in to Hi PG.</li>
                  <li>Open the <strong>Account</strong> tab.</li>
                  <li>Select <strong>Delete account</strong>.</li>
                  <li>Review the consequences, type <strong>DELETE</strong>, and confirm. Email/password owners must also enter their current password.</li>
                </ol>
                %s
                <h2>What is deleted</h2>
                <p>Login identifiers, active sessions, push tokens, profile/contact data, support-message content, identity/KYC files and other private profile files are deleted or irreversibly anonymized. Owner listings are unpublished and future AutoPay is stopped.</p>
                <h2>What may be retained</h2>
                <p>Limited anonymized booking, payment, receipt, tax, fraud-prevention, dispute and legal-acceptance records may be retained where required. Deleting an account does not itself cancel an active accommodation contract or create a refund; contact support first if a stay or payment dispute is open.</p>
                """.formatted(contact));
    }

    private String page(String title, String content) {
        String safeTitle = HtmlUtils.htmlEscape(title);
        return """
                <!doctype html><html lang="en"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width,initial-scale=1">
                <title>%s — Hi PG</title><style>
                body{margin:0;background:#f7f7f5;color:#171717;font:16px/1.65 system-ui,-apple-system,sans-serif}
                main{max-width:820px;margin:0 auto;padding:48px 22px 72px;background:#fff;min-height:100vh}
                h1{font-size:2.25rem;line-height:1.15;margin:0 0 8px}h2{font-size:1.25rem;margin:30px 0 8px}
                .meta{color:#666;margin:0 0 28px}.lead{font-size:1.1rem;color:#333}a{color:#174ea6}
                li{margin:6px 0}.brand{font-weight:800;letter-spacing:-.03em;margin-bottom:28px}
                </style></head><body><main><div class="brand">hi pg</div><h1>%s</h1>
                <p class="meta">Effective %s · Version %s</p>%s</main></body></html>
                """.formatted(safeTitle, safeTitle, EFFECTIVE_DATE,
                AccountDeletionService.RETENTION_POLICY_VERSION, content);
    }

    private String value(String input, String fallback) {
        return HtmlUtils.htmlEscape(input == null || input.isBlank() ? fallback : input.trim());
    }

    private String escapeAttribute(String input) {
        return HtmlUtils.htmlEscape(input == null ? "" : input, "UTF-8");
    }
}
