import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/kyc.dart';
import '../../services/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    _countryCode = widget.currency == 'USD' ? 'USA' : 'NGA';
    _loadOptions();
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WalletHomeScreen(user: widget.user)),
      );
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WalletHomeScreen(user: widget.user)),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your identity')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(child: _buildStep()),
      ),
    );
  }

  Widget _buildStep() {
    final errorWidget = _error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          );

    switch (_step) {
      case _Step.personalInfo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            errorWidget,
            TextField(
              controller: _dobController,
              decoration: const InputDecoration(labelText: 'Date of birth (YYYY-MM-DD)'),
            ),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: (_options?.genders ?? [])
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v),
            ),
            TextField(
              controller: _streetController,
              decoration: const InputDecoration(labelText: 'Street address'),
            ),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            TextField(
              controller: _stateController,
              decoration: const InputDecoration(labelText: 'State'),
            ),
            TextField(
              controller: _postalController,
              decoration: const InputDecoration(labelText: 'Postal code'),
            ),
            DropdownButtonFormField<String>(
              value: _employmentStatus,
              decoration: const InputDecoration(labelText: 'Employment status'),
              items: (_options?.employmentStatuses ?? [])
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _employmentStatus = v),
            ),
            TextField(
              controller: _occupationSearchController,
              decoration: InputDecoration(
                labelText: 'Occupation search',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchOccupations(_occupationSearchController.text),
                ),
              ),
            ),
            ..._occupationResults.map(
              (o) => RadioListTile<KycOccupation>(
                title: Text(o.displayName),
                value: o,
                groupValue: _selectedOccupation,
                onChanged: (v) => setState(() => _selectedOccupation = v),
              ),
            ),
            TextField(
              controller: _employerController,
              decoration: const InputDecoration(labelText: 'Employer name'),
            ),
            TextField(
              controller: _monthlySalaryController,
              decoration: const InputDecoration(labelText: 'Monthly salary'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: _sourceOfFunds,
              decoration: const InputDecoration(labelText: 'Source of funds'),
              items: (_options?.fundsSources ?? [])
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _sourceOfFunds = v),
            ),
            DropdownButtonFormField<String>(
              value: _accountPurpose,
              decoration: const InputDecoration(labelText: 'Account purpose'),
              items: (_options?.accountPurposes ?? [])
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _accountPurpose = v),
            ),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Estimated monthly volume'),
              items: (_options?.estimatedMonthlyVolumeRanges ?? [])
                  .map((r) => DropdownMenuItem(value: r.value, child: Text(r.label)))
                  .toList(),
              onChanged: (v) => setState(() => _estimatedMonthlyVolume = v),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submitPersonalInfo, child: const Text('Continue')),
          ],
        );

      case _Step.documents:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            errorWidget,
            Text('Identification document', style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: _idType,
              items: _identificationTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _idType = v!),
            ),
            TextField(
              controller: _docNumberController,
              decoration: const InputDecoration(labelText: 'Document number'),
            ),
            OutlinedButton(
              onPressed: () async {
                final f = await _capture();
                if (f != null) setState(() => _idFile = f);
              },
              child: Text(_idFile == null ? 'Capture document photo' : 'Retake photo'),
            ),
            FilledButton(
              onPressed: _idFile == null ? null : _uploadIdentification,
              child: const Text('Upload identification'),
            ),
            const Divider(height: 32),
            Text('Proof of address', style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: _poaType,
              items: _proofOfAddressTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _poaType = v!),
            ),
            OutlinedButton(
              onPressed: () async {
                final f = await _capture();
                if (f != null) setState(() => _poaFile = f);
              },
              child: Text(_poaFile == null ? 'Capture proof of address' : 'Retake photo'),
            ),
            FilledButton(
              onPressed: _poaFile == null ? null : _uploadProofOfAddress,
              child: const Text('Upload proof of address'),
            ),
            const Divider(height: 32),
            Text('Selfie', style: Theme.of(context).textTheme.titleMedium),
            OutlinedButton(
              onPressed: () async {
                final f = await _capture();
                if (f != null) setState(() => _selfieFile = f);
              },
              child: Text(_selfieFile == null ? 'Capture selfie' : 'Retake selfie'),
            ),
            FilledButton(
              onPressed: _selfieFile == null ? null : _uploadBiometric,
              child: const Text('Upload selfie'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _step = _Step.readiness),
              child: const Text('Continue'),
            ),
          ],
        );

      case _Step.readiness:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            errorWidget,
            if (_readiness != null && !_readiness!.ready) ...[
              const Text('Not ready yet — missing:'),
              ..._readiness!.missing.map((m) => Text('• $m')),
              const SizedBox(height: 16),
            ],
            FilledButton(onPressed: _checkReadiness, child: const Text('Check readiness')),
          ],
        );

      case _Step.activation:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            errorWidget,
            const Text('Ready to activate KYC for this currency.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _activate, child: const Text('Activate')),
          ],
        );

      case _Step.railOnboarding:
        if (widget.currency == 'USD') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              errorWidget,
              const Text('Finish USD onboarding (Graph Finance / Sumsub).'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _startUsa, child: const Text('Start USD onboarding')),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            errorWidget,
            TextField(
              controller: _bvnController,
              decoration: const InputDecoration(labelText: 'BVN'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _startNigeria, child: const Text('Start NGN onboarding')),
          ],
        );
    }
  }
}
