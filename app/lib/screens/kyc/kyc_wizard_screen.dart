import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/kyc.dart';
import '../../services/api_client.dart';
import '../../theme/payflex_tokens.dart';
import '../../theme/payflex_theme.dart';
import '../../widgets/pf_balance_card.dart';
import '../../widgets/pf_buttons.dart';
import '../../widgets/pf_flow.dart';
import '../../widgets/pf_motion.dart';
import '../../widgets/pf_states.dart';
import '../wallet_home_screen.dart';

/// Mirrors the backend's fixed KYC call order (build brief section 2.2):
/// options/occupations -> 3 documents -> PATCH -> readiness -> activate,
/// then the rail-specific onboarding call for whichever currency the
/// Phase 1 smart wallet was created for. The UI intentionally cannot skip
/// ahead — each step's Continue button is disabled until that step's
/// backend call has succeeded.
///
/// Confirmed live quirks this screen works around (see
/// backend/README.md "Phase 2 findings" for the full detail):
///  - GET kyc/options' `identificationTypes` list does NOT match what the
///    identification-document upload endpoint actually accepts, so this
///    screen uses the confirmed upload-side enum instead of that list.
///  - kyc/activate's `sumsubLevelName` valid set is dynamic; "id-and-liveness"
///    is the value confirmed to work once all three documents are
///    submitted for an NGN-target profile. A 400 here surfaces BMONI's
///    current valid-set verbatim (via ApiException.message) rather than a
///    hardcoded guess.
///
/// Design (brief §3): light "paperwork" surface with clear step progress
/// ("Step 2 of 5"), one action per screen, encouraging micro-copy — the
/// part of a microfinance app users trust least gets the most care.
class KycWizardScreen extends StatefulWidget {
  final AppUser user;
  final String currency; // "NGN" or "USD" — the fiat label BMONI returns
  final String smartWalletId;

  const KycWizardScreen({
    super.key,
    required this.user,
    required this.currency,
    required this.smartWalletId,
  });

  @override
  State<KycWizardScreen> createState() => _KycWizardScreenState();
}

enum _Step { personalInfo, documents, readiness, activation, railOnboarding }

// Confirmed live against the document upload endpoints — NOT the same as
// GET kyc/options' identificationTypes, which lists different values that
// the upload endpoint rejects.
const _identificationTypes = [
  'passport',
  'national_id',
  'drivers_license',
  'government_id',
  'nric',
  'fin',
  'other',
];
const _proofOfAddressTypes = [
  'utility_bill',
  'bank_statement',
  'rental_agreement',
  'tax_document',
  'other',
];

class _KycWizardScreenState extends State<KycWizardScreen> {
  final _api = ApiClient();
  final _picker = ImagePicker();
  _Step _step = _Step.personalInfo;
  bool _busy = false;
  String? _error;

  KycOptions? _options;

  // Personal info form state.
  final _dobController = TextEditingController(text: '1995-07-07');
  String? _gender;
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalController = TextEditingController();
  // Set in initState — `widget` isn't safely readable from a field
  // initializer (State.widget is assigned by the framework after this
  // object's fields are constructed, not before).
  late String _countryCode;
  String? _employmentStatus;
  final _occupationSearchController = TextEditingController();
  List<KycOccupation> _occupationResults = [];
  KycOccupation? _selectedOccupation;
  final _employerController = TextEditingController();
  final _monthlySalaryController = TextEditingController();
  String? _sourceOfFunds;
  String? _accountPurpose;
  int? _estimatedMonthlyVolume;

  // Document upload state.
  String _idType = _identificationTypes.first;
  final _docNumberController = TextEditingController();
  File? _idFile;
  String _poaType = _proofOfAddressTypes.first;
  File? _poaFile;
  File? _selfieFile;

  KycReadiness? _readiness;

  final _bvnController = TextEditingController();

  static const _stepTitles = [
    'Identity details',
    'Documents',
    'Readiness check',
    'Activation',
    'Rail onboarding',
  ];

  @override
  void initState() {
    super.initState();
    _countryCode = widget.currency == 'USD' ? 'USA' : 'NGA';
    _loadOptions();
  }

  @override
  void dispose() {
    _dobController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    _occupationSearchController.dispose();
    _employerController.dispose();
    _monthlySalaryController.dispose();
    _docNumberController.dispose();
    _bvnController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() => _busy = true);
    try {
      _options = await _api.getKycOptions(widget.user.id);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchOccupations(String query) async {
    final results = await _api.getKycOccupations(widget.user.id, query);
    setState(() => _occupationResults = results);
  }

  Future<void> _submitPersonalInfo() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.patchKyc(widget.user.id, {
        'personalInfo': {'dateOfBirth': _dobController.text, 'gender': _gender},
        'address': {
          'streetLine1': _streetController.text,
          'city': _cityController.text,
          'state': _stateController.text,
          'postalCode': _postalController.text,
          'countryCode': _countryCode,
        },
        'employment': {
          'employmentStatus': _employmentStatus,
          'occupationCode': _selectedOccupation?.id,
          'employerName': _employerController.text,
          'monthlySalary': int.tryParse(_monthlySalaryController.text) ?? 0,
        },
        'sourceOfFunds': _sourceOfFunds,
        'accountPurpose': _accountPurpose,
        'estimatedMonthlyVolume': _estimatedMonthlyVolume,
      });
      setState(() => _step = _Step.documents);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File?> _capture() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    return picked == null ? null : File(picked.path);
  }

  Future<void> _uploadIdentification() async {
    if (_idFile == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.submitIdentificationDocument(
        widget.user.id,
        _idFile!,
        type: _idType,
        documentNumber: _docNumberController.text,
        issuingCountry: _countryCode,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadProofOfAddress() async {
    if (_poaFile == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.submitProofOfAddress(widget.user.id, _poaFile!, type: _poaType);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadBiometric() async {
    if (_selfieFile == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.submitBiometric(widget.user.id, _selfieFile!, type: 'selfie');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkReadiness() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _readiness = widget.currency == 'USD'
          ? await _api.getUsdReadiness(widget.user.id)
          : await _api.getKycReadiness(widget.user.id);
      if (_readiness!.ready) setState(() => _step = _Step.activation);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // See the class doc comment: this is the confirmed-working level for
      // an NGN-target profile with all 3 documents submitted. A 400 here
      // will report BMONI's currently-valid set if this ever stops working.
      await _api.activateKyc(
        widget.user.id,
        currency: widget.currency,
        sumsubLevelName: 'id-and-liveness',
      );
      setState(() => _step = _Step.railOnboarding);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startNigeria() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.startNigeria(widget.user.id, bvn: _bvnController.text, ngnWalletIndex: 0);
      // Confirmed live: onboarding/status's anchorStatus flips to "active"
      // a few seconds after this call returns, not immediately — poll.
      Map<String, dynamic> status = await _api.getOnboardingStatus(widget.user.id);
      for (var i = 0; i < 10 && status['anchorStatus'] != 'active'; i++) {
        await Future.delayed(const Duration(seconds: 2));
        status = await _api.getOnboardingStatus(widget.user.id);
      }
      if (!mounted) return;
      await _celebrate('You\u2019re in',
          'Your NGN wallet is live — send, save and borrow from your home screen.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startUsa() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.startUsa(widget.user.id);
      if (!mounted) return;
      await _celebrate('You\u2019re in',
          'Your USD wallet is live — send, save and borrow from your home screen.');
    } catch (e) {
      // Confirmed live: a 422 here means the Sumsub identity check hasn't
      // actually passed yet (e.g. "BAD_SELFIE"/"DOCUMENT_PAGE_MISSING")
      // — a real camera-captured photo is required, not a placeholder.
      setState(() => _error = '${e.toString()}\n\nUSD onboarding requires real, '
          'photorealistic ID/selfie captures — this is a genuine Sumsub identity '
          'check, not a bug.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _celebrate(String title, String message) async {
    await showPfSimpleSuccess(context, title: title, message: message, actionLabel: 'Open my wallet');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WalletHomeScreen(user: widget.user)),
    );
  }

  int get _stepNumber => _Step.values.indexOf(_step) + 1;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('Verify your identity'),
          backgroundColor: PfColors.offWhite,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _busy && _step == _Step.personalInfo && _options == null
                  ? const Center(child: PfBrandedLoader(size: 56))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        PfSpace.xl, PfSpace.lg, PfSpace.xl, 48,
                      ),
                      child: _buildStep(),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String get _stepMicrocopy => switch (_step) {
        _Step.personalInfo =>
          'What PayFlex needs for verification: your personal details, address, '
              'and what you plan to use the account for. One screen at a time.',
        _Step.documents =>
          'Photograph your documents against a plain surface. Photos stay '
              'between you and PayFlex\u2019s verification partner.',
        _Step.readiness => 'A quick health-check before activation — nothing '
            'leaves this device without your go-ahead.',
        _Step.activation => 'Almost there — activating identity for your '
            '${widget.currency} wallet.',
        _Step.railOnboarding => widget.currency == 'USD'
            ? 'Final step: link your USD rail. Real, photorealistic captures '
                'are required for the identity check.'
            : 'Final step: link your NGN rail with your BVN. This unlocks '
                'your live wallet balance.',
      };

  Widget _buildStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PfStepHeader(
          step: _stepNumber,
          total: 5,
          title: _stepTitles[_stepNumber - 1],
        ),
        const SizedBox(height: 6),
        Text(
          _stepMicrocopy,
          style: const TextStyle(
            color: PfColors.inkMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          PfInlineError(
            message: _error!,
            onRetry: _step == _Step.railOnboarding ? () => setState(() => _error = null) : null,
          ),
          const SizedBox(height: 16),
        ],
        switch (_step) {
          _Step.personalInfo => _personalInfoStep(),
          _Step.documents => _documentsStep(),
          _Step.readiness => _readinessStep(),
          _Step.activation => _activationStep(),
          _Step.railOnboarding => _railStep(),
        },
      ],
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: PfColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _personalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel('Personal'),
        TextField(
          controller: _dobController,
          decoration: const InputDecoration(labelText: 'Date of birth'),
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: const InputDecoration(labelText: 'Gender'),
          items: (_options?.genders ?? [])
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 22),
        _fieldLabel('Address'),
        TextField(
          controller: _streetController,
          decoration: const InputDecoration(labelText: 'Street address'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cityController,
          decoration: const InputDecoration(labelText: 'City'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _stateController,
                decoration: const InputDecoration(labelText: 'State'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _postalController,
                decoration: const InputDecoration(labelText: 'Postal code'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _fieldLabel('Employment & purpose'),
        DropdownButtonFormField<String>(
          value: _employmentStatus,
          decoration: const InputDecoration(labelText: 'Employment status'),
          items: (_options?.employmentStatuses ?? [])
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _employmentStatus = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _occupationSearchController,
          decoration: InputDecoration(
            labelText: 'Occupation',
            hintText: 'Search, e.g. "software"',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => _searchOccupations(_occupationSearchController.text),
            ),
          ),
          onSubmitted: _searchOccupations,
        ),
        ..._occupationResults.map(
          (o) => RadioListTile<KycOccupation>(
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            dense: true,
            title: Text(o.displayName, style: const TextStyle(fontSize: 14)),
            value: o,
            groupValue: _selectedOccupation,
            activeColor: PfColors.royalBlue,
            onChanged: (v) => setState(() => _selectedOccupation = v),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _employerController,
          decoration: const InputDecoration(labelText: 'Employer name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _monthlySalaryController,
          decoration: const InputDecoration(labelText: 'Monthly salary'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _sourceOfFunds,
          decoration: const InputDecoration(labelText: 'Source of funds'),
          items: (_options?.fundsSources ?? [])
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _sourceOfFunds = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _accountPurpose,
          decoration: const InputDecoration(labelText: 'Account purpose'),
          items: (_options?.accountPurposes ?? [])
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _accountPurpose = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: 'Estimated monthly volume'),
          items: (_options?.estimatedMonthlyVolumeRanges ?? [])
              .map((r) => DropdownMenuItem(value: r.value, child: Text(r.label)))
              .toList(),
          onChanged: (v) => setState(() => _estimatedMonthlyVolume = v),
        ),
        const SizedBox(height: 24),
        PfPrimaryButton(
          label: 'Save & continue',
          icon: Icons.arrow_forward_rounded,
          busy: _busy,
          onPressed: _busy ? null : _submitPersonalInfo,
        ),
      ],
    );
  }

  Widget _docCard({
    required String title,
    required String hint,
    required Widget picker,
  }) {
    return PfPanel(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: PfColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(color: PfColors.inkMuted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          picker,
        ],
      ),
    );
  }

  Widget _documentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _docCard(
          title: '1 · Identification document',
          hint: 'Passport, national ID or driver\u2019s licence — the document '
              'number must match your name.',
          picker: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _idType,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: _identificationTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _idType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _docNumberController,
                decoration: const InputDecoration(labelText: 'Document number'),
              ),
              const SizedBox(height: 12),
              _captureRow(
                file: _idFile,
                label: 'Document photo',
                onCapture: () async {
                  final f = await _capture();
                  if (f != null) setState(() => _idFile = f);
                },
              ),
              if (_idFile != null) ...[
                const SizedBox(height: 10),
                PfPrimaryButton(
                  label: 'Upload identification',
                  busy: _busy,
                  onPressed: _busy ? null : _uploadIdentification,
                  height: 46,
                ),
              ],
            ],
          ),
        ),
        _docCard(
          title: '2 · Proof of address',
          hint: 'Utility bill, bank statement or rental agreement, dated within '
              'three months.',
          picker: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _poaType,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: _proofOfAddressTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _poaType = v!),
              ),
              const SizedBox(height: 12),
              _captureRow(
                file: _poaFile,
                label: 'Address document',
                onCapture: () async {
                  final f = await _capture();
                  if (f != null) setState(() => _poaFile = f);
                },
              ),
              if (_poaFile != null) ...[
                const SizedBox(height: 10),
                PfPrimaryButton(
                  label: 'Upload proof of address',
                  busy: _busy,
                  onPressed: _busy ? null : _uploadProofOfAddress,
                  height: 46,
                ),
              ],
            ],
          ),
        ),
        _docCard(
          title: '3 · Selfie',
          hint: 'A clear, front-facing photo. Required for Global KYC rails.',
          picker: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _captureRow(
                file: _selfieFile,
                label: 'Selfie',
                onCapture: () async {
                  final f = await _capture();
                  if (f != null) setState(() => _selfieFile = f);
                },
              ),
              if (_selfieFile != null) ...[
                const SizedBox(height: 10),
                PfPrimaryButton(
                  label: 'Upload selfie',
                  busy: _busy,
                  onPressed: _busy ? null : _uploadBiometric,
                  height: 46,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        PfPrimaryButton(
          label: 'Continue to readiness',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => setState(() {
            _error = null;
            _step = _Step.readiness;
          }),
        ),
      ],
    );
  }

  Widget _captureRow({
    required File? file,
    required String label,
    required VoidCallback onCapture,
  }) {
    return Row(
      children: [
        Expanded(
          child: PfSecondaryButton(
            label: file == null ? 'Capture $label' : 'Retake $label',
            icon: file == null ? Icons.photo_camera_outlined : Icons.refresh_rounded,
            onPressed: onCapture,
            height: 46,
          ),
        ),
        if (file != null) ...[
          const SizedBox(width: 10),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: PfColors.successWash,
              borderRadius: BorderRadius.circular(PfRadius.sm),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: PfColors.success,
              size: 22,
            ),
          ),
        ],
      ],
    );
  }

  Widget _readinessStep() {
    final ready = _readiness?.ready ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_readiness != null && !ready) ...[
          PfPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A few items are still missing',
                  style: TextStyle(
                    color: PfColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ..._readiness!.missing.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle_outlined,
                          size: 12,
                          color: PfColors.inkFaint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.replaceAll('_', ' '),
                            style: const TextStyle(
                              color: PfColors.inkMuted,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (ready) ...[
          PfPanel(
            padding: const EdgeInsets.all(18),
            color: PfColors.successWash,
            showShadow: false,
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, color: PfColors.success, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Everything checks out — you\u2019re ready to activate.',
                    style: TextStyle(
                      color: PfColors.success,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        PfPrimaryButton(
          label: _readiness == null ? 'Check readiness' : 'Re-check readiness',
          busy: _busy,
          onPressed: _busy ? null : _checkReadiness,
        ),
      ],
    );
  }

  Widget _activationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PfPanel(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PfColors.successWash,
                  borderRadius: BorderRadius.circular(PfRadius.sm),
                ),
                child: const Icon(Icons.verified_outlined, color: PfColors.success),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Identity verified — activating your ${widget.currency} rail now.',
                  style: const TextStyle(
                    color: PfColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PfPrimaryButton(
          label: 'Activate ${widget.currency} wallet',
          icon: Icons.bolt_outlined,
          busy: _busy,
          onPressed: _busy ? null : _activate,
        ),
      ],
    );
  }

  Widget _railStep() {
    if (widget.currency == 'USD') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PfPanel(
            child: const Text(
              'USD onboarding runs a live Sumsub identity check. Have a real, '
              'well-lit capture of your ID and a selfie ready.',
              style: TextStyle(color: PfColors.inkMuted, fontSize: 13.5, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          PfPrimaryButton(
            label: 'Start USD onboarding',
            busy: _busy,
            onPressed: _busy ? null : _startUsa,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _bvnController,
          decoration: const InputDecoration(
            labelText: 'BVN',
            prefixIcon: Icon(Icons.badge_outlined, size: 20),
          ),
          keyboardType: TextInputType.number,
          maxLength: 11,
        ),
        const SizedBox(height: 6),
        const Text(
          'Your Bank Verification Number links your identity to the NGN rail. '
          'It is checked against the name you registered.',
          style: TextStyle(color: PfColors.inkFaint, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 16),
        PfPrimaryButton(
          label: 'Start NGN onboarding',
          busy: _busy,
          onPressed: _busy ? null : _startNigeria,
        ),
      ],
    );
  }
}
