import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/business_model.dart';
import '../../models/business_category_config.dart';
import '../../services/business_service.dart';
import '../../services/location services/geocoding_service.dart';
import '../home/main_navigation_screen.dart';

/// Multi-step wizard for setting up or editing a business profile
class BusinessSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final BusinessModel? existingBusiness; // For editing mode

  const BusinessSetupScreen({
    super.key,
    this.onComplete,
    this.onSkip,
    this.existingBusiness,
  });

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Category Selection (NEW)
  BusinessCategory? _selectedCategory;

  // Step 2: Sub-type Selection (NEW)
  String? _selectedSubType;

  // Step 3: Basic Info
  final _businessNameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _logoFile;

  // Step 4: Contact Info
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _whatsappController = TextEditingController();

  // Step 5: Address
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();

  // Location search
  final _locationSearchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  // Step 6: Category-specific settings & Hours
  bool _useDefaultHours = true;
  Map<String, dynamic> _categoryData = {};

  final BusinessService _businessService = BusinessService();
  final ImagePicker _imagePicker = ImagePicker();

  static const int _totalSteps = 6;

  // Check if we're in editing mode
  bool get _isEditing => widget.existingBusiness != null;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Pre-populate fields if editing
    if (_isEditing) {
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final business = widget.existingBusiness!;

    // Category
    _selectedCategory = business.category;
    _selectedSubType = business.subType;
    _categoryData = business.categoryData ?? {};

    // Basic Info
    _businessNameController.text = business.businessName;
    _legalNameController.text = business.legalName ?? '';
    _descriptionController.text = business.description ?? '';

    // Contact Info
    _phoneController.text = business.contact.phone ?? '';
    _emailController.text = business.contact.email ?? '';
    _websiteController.text = business.contact.website ?? '';
    _whatsappController.text = business.contact.whatsapp ?? '';

    // Address
    if (business.address != null) {
      _streetController.text = business.address!.street ?? '';
      _cityController.text = business.address!.city ?? '';
      _stateController.text = business.address!.state ?? '';
      _countryController.text = business.address!.country ?? '';
      _postalCodeController.text = business.address!.postalCode ?? '';
    }

    // Hours
    _useDefaultHours = business.hours != null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _businessNameController.dispose();
    _legalNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _whatsappController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _locationSearchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (!_validateCurrentStep()) return;

      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      _saveAndContinue();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Category Selection
        if (_selectedCategory == null) {
          _showError('Please select a business category');
          return false;
        }
        return true;
      case 1: // Sub-type Selection
        if (_selectedSubType == null) {
          _showError('Please select your business type');
          return false;
        }
        return true;
      case 2: // Basic Info
        if (_businessNameController.text.trim().isEmpty) {
          _showError('Please enter your business name');
          return false;
        }
        return true;
      case 3: // Contact
        if (_phoneController.text.trim().isEmpty &&
            _emailController.text.trim().isEmpty) {
          _showError('Please provide at least a phone or email');
          return false;
        }
        return true;
      case 4: // Address
        // Address is optional
        return true;
      case 5: // Category Settings & Hours
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickLogo() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _logoFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking logo: $e');
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);

    try {
      // Quick network connectivity check
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        _showError('No internet connection. Please connect and try again.');
        setState(() => _isLoading = false);
        return;
      }

      // Real internet connectivity test (checks if we can actually reach the internet)
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw const SocketException('No internet');
        }
      } on SocketException catch (_) {
        _showError('No internet connection. Please check your network and try again.');
        setState(() => _isLoading = false);
        return;
      } on TimeoutException catch (_) {
        _showError('Network is slow. Please check your connection and try again.');
        setState(() => _isLoading = false);
        return;
      }

      // Upload logo if selected (with timeout)
      String? logoUrl;
      if (_logoFile != null) {
        logoUrl = await _businessService.uploadLogo(_logoFile!)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Logo upload timed out'),
            );
      } else if (_isEditing) {
        // Keep existing logo if no new one selected
        logoUrl = widget.existingBusiness!.logo;
      }

      // Build contact
      final contact = BusinessContact(
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        whatsapp: _whatsappController.text.trim().isEmpty
            ? null
            : _whatsappController.text.trim(),
      );

      // Build address
      BusinessAddress? address;
      if (_cityController.text.trim().isNotEmpty ||
          _streetController.text.trim().isNotEmpty) {
        address = BusinessAddress(
          street: _streetController.text.trim().isEmpty
              ? null
              : _streetController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          country: _countryController.text.trim().isEmpty
              ? null
              : _countryController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
        );
      }

      // Build business model with new category fields
      final business = BusinessModel(
        id: _isEditing ? widget.existingBusiness!.id : '',
        userId: _isEditing ? widget.existingBusiness!.userId : '',
        businessName: _businessNameController.text.trim(),
        legalName: _legalNameController.text.trim().isEmpty
            ? null
            : _legalNameController.text.trim(),
        businessType: _selectedSubType ?? 'Other',
        category: _selectedCategory,
        subType: _selectedSubType,
        categoryData: _categoryData.isNotEmpty ? _categoryData : null,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        logo: logoUrl,
        contact: contact,
        address: address,
        hours: _useDefaultHours ? BusinessHours.defaultHours() : null,
        // Preserve existing values when editing
        coverImage: _isEditing ? widget.existingBusiness!.coverImage : null,
        rating: _isEditing ? widget.existingBusiness!.rating : 0.0,
        reviewCount: _isEditing ? widget.existingBusiness!.reviewCount : 0,
        followerCount: _isEditing ? widget.existingBusiness!.followerCount : 0,
        isVerified: _isEditing ? widget.existingBusiness!.isVerified : false,
        isActive: _isEditing ? widget.existingBusiness!.isActive : true,
      );

      bool success;
      if (_isEditing) {
        // Update existing business (with timeout)
        success = await _businessService.updateBusiness(
          widget.existingBusiness!.id,
          business,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Update timed out. Please check your connection.'),
        );
      } else {
        // Create new business (with timeout)
        final businessId = await _businessService.createBusiness(business)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw TimeoutException('Creation timed out. Please check your connection.'),
            );
        success = businessId != null;
      }

      if (success) {
        HapticFeedback.heavyImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing
                  ? 'Business updated successfully'
                  : 'Business created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (widget.onComplete != null) {
          widget.onComplete!();
        } else if (_isEditing) {
          // Go back to dashboard when editing
          if (mounted) Navigator.pop(context, true);
        } else {
          _navigateToMainScreen();
        }
      } else {
        _showError(_isEditing
            ? 'Failed to update business. Please try again.'
            : 'Failed to create business. Please try again.');
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout saving business: $e');
      _showError('Connection timed out. Please check your internet and try again.');
    } on SocketException catch (_) {
      _showError('No internet connection. Please check your network.');
    } catch (e) {
      debugPrint('Error saving business: $e');
      if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('resolve')) {
        _showError('Network error. Please check your internet connection.');
      } else {
        _showError('An error occurred. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _skipSetup() {
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      _navigateToMainScreen();
    }
  }

  void _navigateToMainScreen() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildCategorySelectionPage(),
                  _buildSubTypeSelectionPage(),
                  _buildBasicInfoPage(),
                  _buildContactPage(),
                  _buildAddressPage(),
                  _buildCategorySettingsPage(),
                ],
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                IconButton(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                )
              else
                const SizedBox(width: 48),
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: _isEditing ? () => Navigator.pop(context) : _skipSetup,
                child: Text(
                  _isEditing ? 'Cancel' : 'Skip',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_totalSteps, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index > 0 ? 4 : 0,
                    right: index < _totalSteps - 1 ? 4 : 0,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentStep >= index
                          ? const Color(0xFF00D67D)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ============ STEP 1: CATEGORY SELECTION ============
  Widget _buildCategorySelectionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'What type of\nbusiness?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Select the category that best describes your business.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Category Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: BusinessCategoryConfig.all.length,
            itemBuilder: (context, index) {
              final config = BusinessCategoryConfig.all[index];
              final isSelected = _selectedCategory == config.category;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedCategory = config.category;
                    _selectedSubType = null; // Reset sub-type when category changes
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? config.color.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? config.color : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: config.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          config.icon,
                          color: config.color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        config.displayName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Icon(
                          Icons.check_circle,
                          color: config.color,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ============ STEP 2: SUB-TYPE SELECTION ============
  Widget _buildSubTypeSelectionPage() {
    final config = _selectedCategory != null
        ? BusinessCategoryConfig.getConfig(_selectedCategory!)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          Text(
            'What kind of\n${config?.displayName.toLowerCase() ?? "business"}?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Select the specific type of your business.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Sub-type chips
          if (config != null)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: config.subTypes.map((subType) {
                final isSelected = _selectedSubType == subType;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedSubType = subType;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? config.color.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? config.color : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check_circle,
                            color: config.color,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          subType,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ============ STEP 3: BASIC INFO ============
  Widget _buildBasicInfoPage() {
    final config = _selectedCategory != null
        ? BusinessCategoryConfig.getConfig(_selectedCategory!)
        : null;
    final accentColor = config?.color ?? const Color(0xFF00D67D);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Header with gradient text effect
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.white, Colors.white.withValues(alpha: 0.8)],
            ).createShader(bounds),
            child: Text(
              _isEditing ? 'Edit your\nbusiness' : 'Tell us about\nyour business',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _isEditing
                ? 'Update your business profile information.'
                : 'This information will be displayed on your business profile.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 36),

          // Modern Logo Picker with gradient border
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.5),
                          const Color(0xFF6366F1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1A2E),
                        image: _logoFile != null
                            ? DecorationImage(
                                image: FileImage(_logoFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _logoFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: accentColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Logo',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _logoFile == null ? 'Tap to upload' : 'Tap to change',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Form Card with glassmorphism effect
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.business_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Business Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Business Name
                    _buildModernTextField(
                      controller: _businessNameController,
                      label: 'Business Name',
                      hint: 'e.g., Acme Corporation',
                      icon: Icons.store_rounded,
                      isRequired: true,
                      accentColor: accentColor,
                    ),

                    const SizedBox(height: 20),

                    // Legal Name
                    _buildModernTextField(
                      controller: _legalNameController,
                      label: 'Legal/Registered Name',
                      hint: 'If different from business name',
                      icon: Icons.badge_rounded,
                      isRequired: false,
                      accentColor: accentColor,
                    ),

                    const SizedBox(height: 20),

                    // Description
                    _buildModernTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Tell customers about your business...',
                      icon: Icons.description_rounded,
                      maxLines: 4,
                      maxLength: 500,
                      accentColor: accentColor,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tips Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.1),
                  accentColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pro Tip',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A compelling description helps customers understand what makes your business unique.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // Modern text field with better styling
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Text Field
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
              counterStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines > 1 ? 16 : 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ STEP 4: CONTACT ============
  Widget _buildContactPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'Contact\ninformation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'How can customers reach you?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Phone
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: '+91 98765 43210',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 16),

          // Email
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'business@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 16),

          // Website
          _buildTextField(
            controller: _websiteController,
            label: 'Website (Optional)',
            hint: 'https://www.example.com',
            icon: Icons.language_outlined,
            keyboardType: TextInputType.url,
          ),

          const SizedBox(height: 16),

          // WhatsApp
          _buildTextField(
            controller: _whatsappController,
            label: 'WhatsApp (Optional)',
            hint: '+91 98765 43210',
            icon: Icons.chat_outlined,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'At least one contact method is required so customers can reach you.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ============ STEP 5: ADDRESS ============

  // Search for location
  void _searchLocation(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await GeocodingService.searchLocation(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Error searching location: $e');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
      }
    });
  }

  // Select a location from search results
  void _selectLocation(Map<String, dynamic> location) {
    HapticFeedback.selectionClick();

    setState(() {
      // Auto-fill address fields
      _streetController.text = location['area'] ?? '';
      _cityController.text = location['city'] ?? '';
      _stateController.text = location['state'] ?? '';
      _countryController.text = location['country'] ?? '';
      _postalCodeController.text = location['pincode'] ?? '';

      // Clear search
      _locationSearchController.clear();
      _searchResults = [];
    });

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Location added'),
        backgroundColor: const Color(0xFF00D67D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildAddressPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'Business\nlocation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Where is your business located? (Optional)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // Location Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _locationSearchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _searchLocation,
                  decoration: InputDecoration(
                    hintText: 'Search for a location...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00D67D),
                                ),
                              ),
                            ),
                          )
                        : _locationSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  setState(() {
                                    _locationSearchController.clear();
                                    _searchResults = [];
                                  });
                                },
                              )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),

                // Search Results
                if (_searchResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final location = _searchResults[index];
                        return InkWell(
                          onTap: () => _selectLocation(location),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: index < _searchResults.length - 1
                                  ? Border(
                                      bottom: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.05),
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00D67D).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF00D67D),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        location['display'] ?? location['formatted'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (location['city'] != null || location['state'] != null)
                                        Text(
                                          [
                                            location['city'],
                                            location['state'],
                                            location['country'],
                                          ].where((e) => e != null && e.toString().isNotEmpty).join(', '),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.add_circle_outline,
                                  color: Color(0xFF00D67D),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Or divider
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or enter manually',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Street
          _buildTextField(
            controller: _streetController,
            label: 'Street Address',
            hint: '123 Main Street',
            icon: Icons.location_on_outlined,
          ),

          const SizedBox(height: 16),

          // City & State row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'Mumbai',
                  icon: Icons.location_city_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _stateController,
                  label: 'State',
                  hint: 'Maharashtra',
                  icon: Icons.map_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Country & Postal Code row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _countryController,
                  label: 'Country',
                  hint: 'India',
                  icon: Icons.flag_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _postalCodeController,
                  label: 'Postal Code',
                  hint: '400001',
                  icon: Icons.markunread_mailbox_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ============ STEP 6: CATEGORY SETTINGS & HOURS ============
  Widget _buildCategorySettingsPage() {
    final config = _selectedCategory != null
        ? BusinessCategoryConfig.getConfig(_selectedCategory!)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'Almost\ndone!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Set up your business hours and additional details.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Category-specific setup fields
          if (config != null && config.setupFields.isNotEmpty) ...[
            Text(
              '${config.displayName} Settings',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...config.setupFields.map((field) => _buildSetupField(field, config)),
            const SizedBox(height: 24),
          ],

          // What's next card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D67D).withValues(alpha: 0.15),
                  const Color(0xFF00D67D).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00D67D).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.rocket_launch,
                      color: Color(0xFF00D67D),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'After setup, you can:',
                      style: TextStyle(
                        color: Color(0xFF00D67D),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(_getFeatureIconForCategory(), _getFeatureTextForCategory()),
                _buildFeatureItem(Icons.photo_library, 'Upload photos & gallery'),
                _buildFeatureItem(Icons.star, 'Collect customer reviews'),
                _buildFeatureItem(Icons.analytics, 'Track your performance'),
                _buildFeatureItem(Icons.share, 'Share on social media'),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  IconData _getFeatureIconForCategory() {
    switch (_selectedCategory) {
      case BusinessCategory.hospitality:
        return Icons.hotel;
      case BusinessCategory.foodBeverage:
        return Icons.restaurant_menu;
      case BusinessCategory.retail:
      case BusinessCategory.grocery:
        return Icons.shopping_bag;
      case BusinessCategory.beautyWellness:
        return Icons.spa;
      case BusinessCategory.healthcare:
        return Icons.medical_services;
      case BusinessCategory.professional:
      case BusinessCategory.legal:
      case BusinessCategory.financial:
        return Icons.work;
      case BusinessCategory.education:
        return Icons.school;
      case BusinessCategory.fitness:
        return Icons.fitness_center;
      case BusinessCategory.automotive:
        return Icons.directions_car;
      case BusinessCategory.realEstate:
        return Icons.apartment;
      case BusinessCategory.travelTourism:
        return Icons.flight;
      case BusinessCategory.entertainment:
        return Icons.celebration;
      case BusinessCategory.petServices:
        return Icons.pets;
      case BusinessCategory.homeServices:
        return Icons.home_repair_service;
      case BusinessCategory.technology:
        return Icons.computer;
      case BusinessCategory.transportation:
        return Icons.local_shipping;
      case BusinessCategory.artCreative:
        return Icons.palette;
      case BusinessCategory.construction:
        return Icons.construction;
      case BusinessCategory.agriculture:
        return Icons.agriculture;
      case BusinessCategory.manufacturing:
        return Icons.factory;
      case BusinessCategory.weddingEvents:
        return Icons.cake;
      default:
        return Icons.inventory_2;
    }
  }

  String _getFeatureTextForCategory() {
    switch (_selectedCategory) {
      case BusinessCategory.hospitality:
        return 'Add rooms & manage bookings';
      case BusinessCategory.foodBeverage:
        return 'Create menu & manage orders';
      case BusinessCategory.retail:
      case BusinessCategory.grocery:
        return 'Add products & manage orders';
      case BusinessCategory.beautyWellness:
      case BusinessCategory.healthcare:
      case BusinessCategory.professional:
      case BusinessCategory.homeServices:
      case BusinessCategory.technology:
      case BusinessCategory.legal:
      case BusinessCategory.financial:
      case BusinessCategory.artCreative:
      case BusinessCategory.construction:
        return 'Add services & appointments';
      case BusinessCategory.education:
        return 'Add courses & manage classes';
      case BusinessCategory.fitness:
        return 'Add classes & memberships';
      case BusinessCategory.automotive:
        return 'Add services & vehicles';
      case BusinessCategory.realEstate:
        return 'Add properties & listings';
      case BusinessCategory.travelTourism:
        return 'Add packages & bookings';
      case BusinessCategory.entertainment:
      case BusinessCategory.weddingEvents:
        return 'Add packages & events';
      case BusinessCategory.petServices:
        return 'Add pet services & products';
      case BusinessCategory.transportation:
        return 'Add transport services';
      case BusinessCategory.agriculture:
      case BusinessCategory.manufacturing:
        return 'Add products & orders';
      default:
        return 'Add products & services';
    }
  }

  Widget _buildSetupField(CategorySetupField field, BusinessCategoryConfig config) {
    switch (field.type) {
      case FieldType.multiSelect:
        return _buildMultiSelectField(field, config);
      case FieldType.dropdown:
        return _buildDropdownField(field, config);
      case FieldType.text:
        return _buildTextSetupField(field, config);
      case FieldType.toggle:
        return _buildToggleField(field, config);
      case FieldType.time:
        return _buildTimeField(field, config);
      case FieldType.number:
        return _buildNumberField(field, config);
    }
  }

  Widget _buildTextSetupField(CategorySetupField field, BusinessCategoryConfig config) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: _categoryData[field.id] as String? ?? field.defaultValue,
        onChanged: (value) {
          setState(() {
            _categoryData[field.id] = value;
          });
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: field.label,
          labelStyle: const TextStyle(color: Colors.white70),
          hintText: 'Enter ${field.label.toLowerCase()}',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: config.color, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleField(CategorySetupField field, BusinessCategoryConfig config) {
    final isEnabled = _categoryData[field.id] as bool? ??
        (field.defaultValue?.toLowerCase() == 'true');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              field.label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            Switch(
              value: isEnabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  _categoryData[field.id] = value;
                });
              },
              activeColor: config.color,
              activeTrackColor: config.color.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(CategorySetupField field, BusinessCategoryConfig config) {
    final timeValue = _categoryData[field.id] as String? ?? field.defaultValue ?? '09:00';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () async {
          final parts = timeValue.split(':');
          final initialTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
          );

          final picked = await showTimePicker(
            context: context,
            initialTime: initialTime,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: config.color,
                    surface: const Color(0xFF2D2D44),
                  ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null) {
            setState(() {
              _categoryData[field.id] =
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeValue,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.access_time,
                color: config.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField(CategorySetupField field, BusinessCategoryConfig config) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: (_categoryData[field.id]?.toString()) ?? field.defaultValue,
        onChanged: (value) {
          setState(() {
            _categoryData[field.id] = int.tryParse(value) ?? double.tryParse(value);
          });
        },
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: field.label,
          labelStyle: const TextStyle(color: Colors.white70),
          hintText: 'Enter ${field.label.toLowerCase()}',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: config.color, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectField(CategorySetupField field, BusinessCategoryConfig config) {
    final selectedValues = (_categoryData[field.id] as List<dynamic>?)?.cast<String>() ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (field.options ?? []).map((option) {
              final isSelected = selectedValues.contains(option);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    final current = List<String>.from(selectedValues);
                    if (isSelected) {
                      current.remove(option);
                    } else {
                      current.add(option);
                    }
                    _categoryData[field.id] = current;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? config.color.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? config.color : Colors.white24,
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(CategorySetupField field, BusinessCategoryConfig config) {
    final selectedValue = _categoryData[field.id] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        onChanged: (value) {
          setState(() {
            _categoryData[field.id] = value;
          });
        },
        decoration: InputDecoration(
          labelText: field.label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: config.color, width: 2),
          ),
        ),
        dropdownColor: const Color(0xFF2D2D44),
        style: const TextStyle(color: Colors.white),
        hint: Text('Select ${field.label}', style: const TextStyle(color: Colors.white38)),
        items: (field.options ?? []).map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white54),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D67D), width: 2),
        ),
        counterStyle: const TextStyle(color: Colors.white54),
      ),
    );
  }

  Widget _buildBottomButtons() {
    bool canContinue;
    String buttonText;

    switch (_currentStep) {
      case 0:
        canContinue = _selectedCategory != null;
        buttonText = 'Continue';
        break;
      case 1:
        canContinue = _selectedSubType != null;
        buttonText = 'Continue';
        break;
      case 2:
        canContinue = _businessNameController.text.trim().isNotEmpty;
        buttonText = 'Continue';
        break;
      case 3:
        canContinue = _phoneController.text.trim().isNotEmpty ||
            _emailController.text.trim().isNotEmpty;
        buttonText = 'Continue';
        break;
      case 4:
        canContinue = true;
        buttonText = 'Continue';
        break;
      case 5:
        canContinue = true;
        buttonText = _isEditing ? 'Update Business' : 'Create Business';
        break;
      default:
        canContinue = false;
        buttonText = 'Continue';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                canContinue ? const Color(0xFF00D67D) : Colors.grey[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_currentStep == _totalSteps - 1) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.store, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
