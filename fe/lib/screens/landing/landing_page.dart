import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/access_request_service.dart';
import '../../services/api_client.dart';
import '../../widgets/news_carousel.dart';
import '../auth/login_page.dart';
import '../messages/public_message_sheet.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  /// Identifies the fixed header so tests can assert it clears the status bar.
  static const Key headerKey = Key('landing-header');

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    'home': GlobalKey(),
    'about': GlobalKey(),
    'research': GlobalKey(),
    'join': GlobalKey(),
  };

  String _activeSection = 'home';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --------------------------------------------------- "Join Research" form
  final AccessRequestService _accessRequests = AccessRequestService();
  final GlobalKey<FormState> _joinFormKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _institutionController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;
  String? _joinError;

  /// Breakpoints, matching the ones documented in fe/README.md.
  ///
  /// Below [_desktopBreakpoint] the two-column sections stack vertically.
  /// Without this the page is a fixed desktop layout and overflows on
  /// anything narrower.
  static const double _desktopBreakpoint = 1000;
  static const double _mobileBreakpoint = 600;

  /// The header keeps its inline tabs further down than the section layout
  /// does. The four tabs plus the login button still fit comfortably at this
  /// width, and collapsing them at 1000px hid the navigation on ordinary
  /// laptop windows.
  static const double _navBreakpoint = 760;

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= _desktopBreakpoint;

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < _mobileBreakpoint;

  /// True while the header shows tabs rather than a hamburger.
  bool _isNavInline(BuildContext context) =>
      MediaQuery.of(context).size.width >= _navBreakpoint;

  /// Section gutter: generous on desktop, tight enough to be usable on a phone.
  EdgeInsets _sectionPadding(BuildContext context) => EdgeInsets.symmetric(
    horizontal: _isMobile(context) ? 20 : 40,
    vertical: _isMobile(context) ? 56 : 96,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _institutionController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Determine which section is currently in view. The scroll offset itself
    // is not needed: each section's global position already reflects it.
    String newActiveSection = 'home';

    for (final entry in _sectionKeys.entries) {
      final context = entry.value.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          if (position.dy <= 100) {
            // Within 100px from top
            newActiveSection = entry.key;
          }
        }
      }
    }

    if (newActiveSection != _activeSection) {
      setState(() {
        _activeSection = newActiveSection;
      });
    }
  }

  void _scrollToSection(String section) {
    final key = _sectionKeys[section];
    if (key == null) return;

    // Tunggu sebentar untuk memastikan layout sudah selesai
    Future.delayed(const Duration(milliseconds: 100), () {
      // The page may have been popped during the delay.
      if (!mounted) return;

      final context = key.currentContext;
      if (context == null || !context.mounted) {
        debugPrint('Context for $section is null');
        return;
      }

      try {
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          debugPrint('RenderBox for $section is null');
          return;
        }

        final position = renderBox.localToGlobal(Offset.zero);
        final currentScrollOffset = _scrollController.offset;

        // Karena header sekarang fixed, kita perlu adjust offset
        // Section sudah dimulai dari posisi 64px (setelah spacer)
        // Jadi kita scroll ke position.dy + currentScrollOffset - 64
        final targetScrollOffset = position.dy + currentScrollOffset - 64;

        debugPrint('Scrolling to $section at position: $targetScrollOffset');

        _scrollController.animateTo(
          targetScrollOffset.clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        debugPrint('Error scrolling to $section: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // Painted behind the status bar strip that SafeArea reserves, so the
      // gap reads as part of the header rather than a stray white band.
      backgroundColor: AppTheme.surface,
      drawer: _isNavInline(context) ? null : _buildNavDrawer(context),
      // This page draws its own fixed header inside a Stack instead of using
      // an AppBar, so nothing was reserving room for the system status bar and
      // the header rendered underneath the clock and battery icons.
      body: SelectionArea(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Scrollable content
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    // Spacer untuk header (agar content tidak tertutup header)
                    const SizedBox(height: 64),

                    // Hero Section (Home)
                    Container(
                      key: _sectionKeys['home'],
                      child: _buildHeroSection(context),
                    ),

                    // About Section
                    Container(
                      key: _sectionKeys['about'],
                      child: _buildAboutSection(context),
                    ),

                    // Research Section
                    Container(
                      key: _sectionKeys['research'],
                      child: _buildResearchSection(context),
                    ),

                    // Join Section
                    Container(
                      key: _sectionKeys['join'],
                      child: _buildJoinSection(context),
                    ),

                    // Footer
                    _buildFooter(context),
                  ],
                ),
              ),

              // Fixed Header di atas
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildHeader(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      key: LandingPage.headerKey,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _isNavInline(context) ? 40 : 16,
      ),
      child: Row(
        children: [
          // Logo
          Image.asset('assets/branding/brin_logo.png', width: 24, height: 24),
          const SizedBox(width: 12),
          // `Expanded` and no `Spacer`, rather than `Flexible` plus one.
          //
          // Both `Flexible` and `Spacer` default to flex: 1, so they *split*
          // the free space down the middle. "BRIN" is short and `Flexible` is
          // a loose fit, so the text claimed only ~55px of its 137px share --
          // and the 73px it declined was handed to the row's trailing edge,
          // parking the hamburger well short of the corner instead of against
          // it. `Expanded` is a tight fit that takes every remaining pixel,
          // left-aligning the brand and pinning whatever follows to the right
          // edge. It keeps the overflow guard the `Flexible` was there for.
          Expanded(
            child: Text(
              'BRIN',
              style: Theme.of(context).textTheme.headlineMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Navigation: inline tabs down to _navBreakpoint, a hamburger that
          // opens the drawer below that. Four tabs plus the login button do
          // not fit on a phone.
          // Sign-in lives in exactly one place per layout: beside the tabs on
          // a wide window, and inside the drawer on a phone. Showing it in the
          // header *and* the drawer gave a phone two LOGIN buttons a few
          // hundred pixels apart, and cost the header room it does not have.
          if (_isNavInline(context)) ...[
            _buildNavButton(context, 'home', 'HOME'),
            _buildNavButton(context, 'about', 'ABOUT'),
            _buildNavButton(context, 'research', 'RESEARCH'),
            _buildNavButton(context, 'join', 'JOIN'),
            const SizedBox(width: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              child: const Text('LOGIN'),
            ),
          ] else
            IconButton(
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu, size: 22),
            ),
        ],
      ),
    );
  }

  /// Slide-in navigation for narrow screens, matching the drawer the admin
  /// console uses so both halves of the app behave the same way.
  Widget _buildNavDrawer(BuildContext context) {
    const labels = {
      'home': 'HOME',
      'about': 'ABOUT',
      'research': 'RESEARCH',
      'join': 'JOIN',
    };

    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand block, mirroring the sidebar header in AdminShell.
            Container(
              height: 88,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/branding/brin_logo.png',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'BRIN',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          'Neutron CT Platform',
                          style: Theme.of(context).textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            for (final entry in labels.entries)
              _buildDrawerItem(context, entry.key, entry.value),

            const Spacer(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close the drawer first
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text('LOGIN'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String section, String label) {
    final isActive = _activeSection == section;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _scrollToSection(section);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryLight : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? AppTheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, String section, String label) {
    final isActive = _activeSection == section;

    return TextButton(
      onPressed: () => _scrollToSection(section),
      style: TextButton.styleFrom(
        foregroundColor: isActive ? AppTheme.primary : AppTheme.textPrimary,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            color: isActive ? AppTheme.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final isDesktop = _isDesktop(context);

    // Was a hard-coded `height: 800`. Any viewport shorter than that — or any
    // width narrow enough to make the headline wrap onto extra lines — pushed
    // the column past its box and produced a RenderFlex overflow. A minimum
    // height keeps the desktop proportions without capping the content.
    return Container(
      color: AppTheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile(context) ? 20 : 40,
        vertical: isDesktop ? 64 : 48,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: isDesktop ? 640 : 0),
        child: isDesktop
            ? Row(
                children: [
                  Expanded(flex: 6, child: _buildHeroText(context)),
                  const SizedBox(width: 48),
                  Expanded(flex: 6, child: _buildHeroVisual(context)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroText(context),
                  const SizedBox(height: 40),
                  _buildHeroVisual(context),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroText(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advancing Indonesian Research through Deep Learning',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 8),
        Container(width: 40, height: 4, color: AppTheme.primary),
        const SizedBox(height: 24),
        Text(
          'Execute neural network predictions securely within an institutionally sanctioned environment. A unified research portal designed for accuracy and high-performance computation.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => _scrollToSection('join'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          ),
          child: const Text('EXPLORE CAPABILITIES'),
        ),
      ],
    );
  }

  Widget _buildHeroVisual(BuildContext context) {
    final isDesktop = _isDesktop(context);

    return Container(
      // 600 is far taller than a phone viewport; scale it down off desktop.
      height: isDesktop ? 600 : 280,
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.biotech,
              size: isDesktop ? 120 : 72,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            const Text('BRIN Neural Network Animation'),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: _sectionPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About the Models',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Container(width: 40, height: 4, color: AppTheme.primary),
          const SizedBox(height: 24),
          Text(
            'The BRIN Research Portal provides access to state-of-the-art deep learning models vetted for institutional use. Our infrastructure supports complex data workflows with uncompromising security and reproducibility.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 48),

          // Feature Cards — side by side on desktop, stacked below that.
          // Three columns on a phone leave roughly 100px per card, which is
          // narrower than the card's own 32px padding allows for.
          _buildFeatureCards(context),
        ],
      ),
    );
  }

  Widget _buildFeatureCards(BuildContext context) {
    final cards = <Widget>[
      _buildFeatureCard(
        context,
        Icons.analytics,
        'High-Fidelity Analysis',
        'Deploy validated neural architectures for image classification, time-series forecasting, and natural language processing tasks.',
      ),
      _buildFeatureCard(
        context,
        Icons.security,
        'Sanctioned Environment',
        'All data processing occurs within BRIN\'s secure computational clusters, ensuring compliance with institutional data governance policies.',
      ),
      _buildFeatureCard(
        context,
        Icons.integration_instructions,
        'Streamlined Workflow',
        'Upload datasets via a simple drag-and-drop interface and receive actionable, structured readouts of model confidence and metrics.',
      ),
    ];

    if (!_isDesktop(context)) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            cards[i],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 32),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 48, color: AppTheme.primary),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResearchSection(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: _sectionPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Research Applications',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Container(width: 40, height: 4, color: AppTheme.primary),
          const SizedBox(height: 24),
          Text(
            'Our platform supports critical research in material science, neutron imaging, and computed tomography analysis.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),

          // Renders nothing until an administrator publishes something, so
          // the section reads exactly as before on a fresh install.
          const SizedBox(height: 32),
          const NewsCarousel(),
        ],
      ),
    );
  }

  Widget _buildJoinSection(BuildContext context) {
    final isDesktop = _isDesktop(context);

    return Container(
      color: AppTheme.background,
      padding: _sectionPadding(context),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildJoinCopy(context)),
                const SizedBox(width: 48),
                Expanded(flex: 7, child: _buildJoinForm(context)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildJoinCopy(context),
                const SizedBox(height: 40),
                _buildJoinForm(context),
              ],
            ),
    );
  }

  Widget _buildJoinCopy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Join Research', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Container(width: 40, height: 4, color: AppTheme.primary),
        const SizedBox(height: 24),
        Text(
          'Request access to the neural network portal. Eligibility is currently restricted to registered BRIN researchers, affiliated academic staff, and approved data science graduate students.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accentLight,
            border: Border.all(color: AppTheme.accent),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: AppTheme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Access requests are reviewed weekly by the IT Administration board.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJoinForm(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(_isMobile(context) ? 24 : 40),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: _submitted ? _buildSubmitted(context) : _buildFormFields(context),
    );
  }

  /// Replaces the form once a request goes through, so the applicant is not
  /// left wondering whether it worked and sending it again.
  Widget _buildSubmitted(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 44,
          color: AppTheme.success,
        ),
        const SizedBox(height: 16),
        Text(
          'Request received',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'An administrator will review it and send your account details to '
          '${_emailController.text.trim()}.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() {
            _submitted = false;
            _joinError = null;
          }),
          child: const Text('SUBMIT ANOTHER'),
        ),
      ],
    );
  }

  Widget _buildFormFields(BuildContext context) {
    return Form(
      key: _joinFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormField(
            context,
            'First Name',
            controller: _firstNameController,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'First name is required'
                : null,
          ),
          const SizedBox(height: 24),
          _buildFormField(
            context,
            'Last Name',
            controller: _lastNameController,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Last name is required'
                : null,
          ),
          const SizedBox(height: 24),
          _buildFormField(
            context,
            'Institutional Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildFormField(
            context,
            'Department / Institution',
            controller: _institutionController,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Institution is required'
                : null,
          ),
          const SizedBox(height: 24),
          _buildFormField(
            context,
            'What do you plan to use it for?',
            controller: _reasonController,
            hint: 'Optional, but it speeds up review',
            maxLines: 3,
          ),

          if (_joinError != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                border: Border.all(color: AppTheme.error),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _joinError!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _submitting ? null : _submitJoinRequest,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('SUBMIT REQUEST'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitJoinRequest() async {
    if (!(_joinFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _joinError = null;
    });

    try {
      await _accessRequests.submit(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        institution: _institutionController.text.trim(),
        reason: _reasonController.text,
      );

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // The server writes these for the applicant -- an account that already
        // exists, or a request already queued -- so show them unchanged.
        _joinError = e.message;
      });
    }
  }

  Widget _buildFormField(
    BuildContext context,
    String label, {
    TextEditingController? controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint ?? label),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isDesktop = _isDesktop(context);

    final copyright = Text(
      '© 2026 BRIN Research Portal. All rights reserved.',
      style: Theme.of(context).textTheme.bodySmall,
    );

    // Wrap, not Row: three text buttons do not fit beside the copyright line
    // on a phone. This was the source of the ~579px horizontal overflow.
    final links = Wrap(
      children: [
        TextButton(onPressed: () {}, child: const Text('Privacy Policy')),
        TextButton(onPressed: () {}, child: const Text('Terms of Service')),
        TextButton(
          onPressed: () => showPublicMessageSheet(context),
          child: const Text('Support'),
        ),
      ],
    );

    return Container(
      color: AppTheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile(context) ? 20 : 40,
        vertical: 32,
      ),
      child: isDesktop
          // Flexible keeps the copyright from pushing the links off the edge
          // in the 1000-1200px band, where both only just fit.
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: copyright),
                links,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [links, const SizedBox(height: 12), copyright],
            ),
    );
  }
}
