enum DemoSampleMode {
  message,
  website,
  upi,
}

enum DemoRiskCategory {
  high,
  suspicious,
  low,
}

class DemoSample {
  final String title;
  final String description;
  final String input;
  final DemoSampleMode mode;
  final DemoRiskCategory expectedRisk;

  const DemoSample({
    required this.title,
    required this.description,
    required this.input,
    required this.mode,
    required this.expectedRisk,
  });

  String get riskLabel {
    switch (expectedRisk) {
      case DemoRiskCategory.high:
        return 'High risk';
      case DemoRiskCategory.suspicious:
        return 'Suspicious';
      case DemoRiskCategory.low:
        return 'Low risk';
    }
  }

  String get modeLabel {
    switch (mode) {
      case DemoSampleMode.message:
        return 'Message';
      case DemoSampleMode.website:
        return 'Website';
      case DemoSampleMode.upi:
        return 'UPI';
    }
  }
}

class DemoTestData {
  static const List<DemoSample> samples = [
    // ---------------- HIGH-RISK MESSAGES ----------------

    DemoSample(
      title: 'Bank KYC update',
      description: 'Bank impersonation and urgent KYC request',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
Dear Customer, your SBI Internet Banking access
will be restricted today due to pending KYC verification.

Please complete your verification to avoid interruption:
http://sbi-kyc-help.example.com

Ignore if already updated.
''',
    ),

    DemoSample(
      title: 'UPI refund scam',
      description: 'Suspicious refund collection request',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
Your refund of Rs. 2,499 has been initiated.

To receive the amount, please approve the
collect request sent to your UPI application.

Refund Ref: RF829104
''',
    ),

    DemoSample(
      title: 'Electricity disconnection',
      description: 'Threatening payment and impersonation',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
BESCOM NOTICE:

Your electricity connection is scheduled for
disconnection tonight due to an outstanding bill.

Please contact the officer immediately at
+91 90000 12345 to prevent disconnection.
''',
    ),

    DemoSample(
      title: 'WhatsApp account takeover',
      description: 'Attempt to obtain a verification code',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
Hey, I accidentally sent a verification code
to your number. Can you send it back?

It's a 6-digit code and I need it urgently.
''',
    ),

    DemoSample(
      title: 'Fake parcel customs fee',
      description: 'Unexpected parcel clearance payment',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
Your shipment is currently held at the customs
facility due to incomplete address verification.

Pay the pending clearance charge of Rs. 35
to schedule the final delivery.
''',
    ),

    DemoSample(
      title: 'Fake bank reward',
      description: 'Bank impersonation and PIN request',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
Congratulations! Your debit card is eligible
for an exclusive cashback reward of Rs. 7,500.

To activate your reward, verify your card details
and confirm your banking PIN.
''',
    ),

    DemoSample(
      title: 'Fake customer support',
      description: 'Request for sensitive banking credentials',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
Your UPI transaction is currently under review.

For immediate assistance, contact our
24x7 support executive on WhatsApp.

Keep your registered mobile number and
UPI PIN ready for verification.
''',
    ),

    DemoSample(
      title: 'Internship registration fee',
      description: 'Advance payment for a job opportunity',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
Congratulations! Your profile has been shortlisted
for the Software Development Internship.

Your joining letter will be issued after payment
of a refundable onboarding and verification fee
of Rs. 799.

Complete payment today to reserve your position.
''',
    ),

    DemoSample(
      title: 'Investment doubling scheme',
      description: 'Guaranteed investment returns',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
We are opening 20 exclusive slots for our
AI trading program.

Invest Rs. 5,000 today and receive guaranteed
returns of Rs. 15,000 within 7 days.

DM for payment details.
''',
    ),

    DemoSample(
      title: 'Fake loan approval',
      description: 'Advance fee for loan disbursement',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.high,
      input: '''
Dear Applicant,

Your personal loan of Rs. 3,00,000 has been
pre-approved without income documentation.

Pay a processing fee of Rs. 1,499 to release
the amount into your bank account immediately.
''',
    ),

    // ---------------- SUSPICIOUS MESSAGES ----------------

    DemoSample(
      title: 'Work from home offer',
      description: 'Unsolicited job offer with high earnings',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
Hello! We are hiring part-time workers for
a data entry project.

Work 1-2 hours daily from your mobile phone.
Earn Rs. 800-1500 per day.

No experience required. Send your details
to get started.
''',
    ),

    DemoSample(
      title: 'Parcel address confirmation',
      description: 'Unsolicited request for personal details',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
Your package delivery could not be completed
because the delivery address was incomplete.

Please confirm your address and mobile number
before the parcel is returned to the sender.
''',
    ),

    DemoSample(
      title: 'Unknown UPI request',
      description: 'Unexpected payment request',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
Payment request received.

Sender: Online Services
Amount: Rs. 4,999
Note: Account verification

Open your UPI application to review this request.
''',
    ),

    DemoSample(
      title: 'Social media verification',
      description: 'Account restriction and appeal message',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
Your Instagram account has been reported
for impersonation.

Submit an appeal within 24 hours to avoid
permanent account restrictions.

Our verification team will contact you shortly.
''',
    ),

    DemoSample(
      title: 'Unknown bank transaction',
      description: 'Unfamiliar transaction notification',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
Rs. 18,500 was attempted from your account
at an unfamiliar merchant.

If this transaction was not initiated by you,
reply immediately for assistance.
''',
    ),

    DemoSample(
      title: 'Unrealistic shopping discount',
      description: 'Unusually cheap product and advance payment',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
FLASH SALE!!

Get the latest iPhone for just Rs. 9,999.

Limited stock available. Advance payment required
to confirm your order.

Orders are dispatched within 24 hours.
''',
    ),

    DemoSample(
      title: 'Telegram investment group',
      description: 'Unverified investment claims',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
We provide daily intraday stock recommendations
with 95% accuracy.

Join our VIP Telegram group for exclusive
buy and sell signals.

First 50 members get free access.
''',
    ),

    DemoSample(
      title: 'Unknown document request',
      description: 'Unexpected request to sign in to view a file',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
Hi, please check the attached document.
It contains the updated payment information
for the project.

Open it and sign in using your company email
to view the details.
''',
    ),

    DemoSample(
      title: 'College scholarship offer',
      description: 'Scholarship offer with verification charge',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
Students can receive a scholarship of
Rs. 25,000 under the National Student
Financial Assistance Program.

Registration closes tonight.
A small document verification charge applies.
''',
    ),

    DemoSample(
      title: 'Unexpected login notification',
      description: 'Unfamiliar account activity',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.suspicious,
      input: '''
New login detected from a device
we don't recognise.

Device: Android
Location: Unknown
Time: 02:14 AM

If this wasn't you, review your account
security settings immediately.
''',
    ),

    // ---------------- LOW-RISK MESSAGES ----------------

    DemoSample(
      title: 'Bank transaction alert',
      description: 'Ordinary debit notification',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
Dear Customer, INR 450.00 has been debited
from your account ending 4821.

Transaction date: 31-Oct-2026
Available balance: INR 12,840.50.

If you did not make this transaction,
contact your bank using its official app.
''',
    ),

    DemoSample(
      title: 'College examination notice',
      description: 'Normal academic announcement',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
NOTICE

The Department of Computer Science has
scheduled the internal assessment examination
for Monday, 2 November 2026.

Students are requested to report to their
respective classrooms by 9:30 AM.
''',
    ),

    DemoSample(
      title: 'Delivery update',
      description: 'Normal parcel tracking notification',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
Your order #ORD829104 has been shipped.

Expected delivery: 2 November 2026.

You can track your shipment through the
official shopping application.
''',
    ),

    DemoSample(
      title: 'UPI payment confirmation',
      description: 'Normal payment confirmation',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
Payment successful!

You paid Rs. 250.00 to College Canteen.

UPI transaction ID: 621045789123
Status: Completed

Thank you for using UPI.
''',
    ),

    DemoSample(
      title: 'Password reset confirmation',
      description: 'Ordinary security notification',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
A password reset request was received
for your account.

If you initiated this request, continue
using the official application.

If you did not request it, secure your account.
''',
    ),

    DemoSample(
      title: 'Internship interview invitation',
      description: 'Normal interview scheduling message',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
Hello,

Thank you for applying for the Software
Engineering Internship.

We would like to invite you for a technical
interview on 4 November at 11:00 AM.

Please confirm your availability by replying
to this email.
''',
    ),

    DemoSample(
      title: 'Electricity bill reminder',
      description: 'Normal utility bill notification',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
Dear Consumer,

Your electricity bill for October is now available.

Consumer ID: 1029384756
Amount Due: Rs. 1,245
Due Date: 08-Nov-2026

Please pay through the official electricity
board website or application.
''',
    ),

    DemoSample(
      title: 'Restaurant bill reminder',
      description: 'Normal payment reminder from a friend',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
Hi,

Just a reminder that your share of the
restaurant bill is Rs. 320.

You can send it whenever convenient.
Thanks!
''',
    ),

    DemoSample(
      title: 'GitHub security notification',
      description: 'Normal account security notification',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
Hi,

A new sign-in was detected on your GitHub account.

If this was you, no action is needed.
Otherwise, review your active sessions and
change your password through GitHub settings.
''',
    ),

    DemoSample(
      title: 'College technical fest',
      description: 'Normal college event announcement',
      mode: DemoSampleMode.message,
      expectedRisk: DemoRiskCategory.low,
      input: '''
Hey everyone!

The annual technical fest is happening
this Saturday from 10 AM onwards.

We'll have coding competitions, project
showcases, gaming events and workshops.

Registration details are available through
the college student portal.
''',
    ),

    // ---------------- WEBSITE SAMPLES ----------------

    DemoSample(
      title: 'Fake SBI KYC domain',
      description: 'Bank-themed suspicious domain',
      mode: DemoSampleMode.website,
      expectedRisk: DemoRiskCategory.high,
      input: 'http://sbi-kyc-help.example.com',
    ),

    DemoSample(
      title: 'Fake ICICI update domain',
      description: 'Bank impersonation-style domain',
      mode: DemoSampleMode.website,
      expectedRisk: DemoRiskCategory.high,
      input: 'http://icici-account-update.example.com',
    ),

    DemoSample(
      title: 'Fake PayPal security domain',
      description: 'Payment-service impersonation',
      mode: DemoSampleMode.website,
      expectedRisk: DemoRiskCategory.high,
      input: 'http://paypal-security-check.example.com',
    ),

    DemoSample(
      title: 'Fake Google verification domain',
      description: 'Brand impersonation-style domain',
      mode: DemoSampleMode.website,
      expectedRisk: DemoRiskCategory.suspicious,
      input: 'http://google-account-verify.example.com',
    ),

    DemoSample(
      title: 'GitHub',
      description: 'Known legitimate domain',
      mode: DemoSampleMode.website,
      expectedRisk: DemoRiskCategory.low,
      input: 'https://github.com',
    ),

    DemoSample(
      title: 'Wikipedia',
      description: 'Known legitimate domain',
      mode: DemoSampleMode.website,
      expectedRisk: DemoRiskCategory.low,
      input: 'https://www.wikipedia.org',
    ),

    DemoSample(
      title: 'Microsoft',
      description: 'Known legitimate domain',
      mode: DemoSampleMode.website,
      expectedRisk: DemoRiskCategory.low,
      input: 'https://www.microsoft.com',
    ),

    DemoSample(
      title: 'NPCI',
      description: 'Official NPCI website',
      mode: DemoSampleMode.website,
      expectedRisk: DemoRiskCategory.low,
      input: 'https://www.npci.org.in',
    ),

    // ---------------- UPI SAMPLES ----------------

    DemoSample(
      title: 'Large unknown payment',
      description: 'Large payment to an unknown recipient',
      mode: DemoSampleMode.upi,
      expectedRisk: DemoRiskCategory.suspicious,
      input:
          'upi://pay?pa=unknownseller@upi&pn=OnlineStore&am=25000&cu=INR&tn=OrderPayment',
    ),

    DemoSample(
      title: 'Campus canteen payment',
      description: 'Small merchant payment request',
      mode: DemoSampleMode.upi,
      expectedRisk: DemoRiskCategory.low,
      input:
          'upi://pay?pa=campuscanteen@upi&pn=CampusCanteen&am=120&cu=INR&tn=Lunch',
    ),

    DemoSample(
      title: 'Account verification payment',
      description: 'Payment request with suspicious context',
      mode: DemoSampleMode.upi,
      expectedRisk: DemoRiskCategory.suspicious,
      input:
          'upi://pay?pa=unknownperson@upi&pn=AccountSupport&am=4999&cu=INR&tn=AccountVerification',
    ),

    DemoSample(
      title: 'Friend payment',
      description: 'Small personal transfer',
      mode: DemoSampleMode.upi,
      expectedRisk: DemoRiskCategory.low,
      input:
          'upi://pay?pa=friend123@upi&pn=Rahul&am=350&cu=INR&tn=MovieTickets',
    ),
  ];

  static List<DemoSample> getByRisk(DemoRiskCategory? risk) {
    if (risk == null) return samples;

    return samples.where((sample) {
      return sample.expectedRisk == risk;
    }).toList();
  }

  static List<DemoSample> getByMode(DemoSampleMode? mode) {
    if (mode == null) return samples;

    return samples.where((sample) {
      return sample.mode == mode;
    }).toList();
  }
}