import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../auth/login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
          if (position.dy <= 100) { // Within 100px from top
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
          targetScrollOffset.clamp(0, _scrollController.position.maxScrollExtent),
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
      body: Stack(
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          // Logo
          const Icon(Icons.science, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            'BRIN',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          
          const Spacer(),
          
          // Navigation
          _buildNavButton(context, 'home', 'HOME'),
          _buildNavButton(context, 'about', 'ABOUT'),
          _buildNavButton(context, 'research', 'RESEARCH'),
          _buildNavButton(context, 'join', 'JOIN'),
          
          const SizedBox(width: 24),
          
          // Login Button
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('LOGIN'),
          ),
        ],
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
    return Container(
      height: 800,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: Row(
          children: [
            // Text Content
            Expanded(
              flex: 6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Advancing Indonesian Research through Deep Learning',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Execute neural network predictions securely within an institutionally sanctioned environment. A unified research portal designed for accuracy and high-performance computation.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => _scrollToSection('join'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                    ),
                    child: const Text('EXPLORE CAPABILITIES'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 48),
            
            // Animation Area (Placeholder)
            Expanded(
              flex: 6,
              child: Container(
                height: 600,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.biotech, size: 120, color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text('BRIN Neural Network Animation'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About the Models',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'The BRIN Research Portal provides access to state-of-the-art deep learning models vetted for institutional use. Our infrastructure supports complex data workflows with uncompromising security and reproducibility.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 48),
          
          // Feature Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildFeatureCard(
                  context,
                  Icons.analytics,
                  'High-Fidelity Analysis',
                  'Deploy validated neural architectures for image classification, time-series forecasting, and natural language processing tasks.',
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: _buildFeatureCard(
                  context,
                  Icons.security,
                  'Sanctioned Environment',
                  'All data processing occurs within BRIN\'s secure computational clusters, ensuring compliance with institutional data governance policies.',
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: _buildFeatureCard(
                  context,
                  Icons.integration_instructions,
                  'Streamlined Workflow',
                  'Upload datasets via a simple drag-and-drop interface and receive actionable, structured readouts of model confidence and metrics.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, IconData icon, String title, String description) {
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
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Research Applications',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Our platform supports critical research in material science, neutron imaging, and computed tomography analysis.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinSection(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 96),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join Research',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Request access to the neural network portal. Eligibility is currently restricted to registered BRIN researchers, affiliated academic staff, and approved data science graduate students.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
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
            ),
          ),
          
          const SizedBox(width: 48),
          
          Expanded(
            flex: 7,
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form fields (placeholder)
                  _buildFormField(context, 'First Name'),
                  const SizedBox(height: 24),
                  _buildFormField(context, 'Last Name'),
                  const SizedBox(height: 24),
                  _buildFormField(context, 'Institutional Email'),
                  const SizedBox(height: 24),
                  _buildFormField(context, 'Department / Institution'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      // Submit form
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Access request submitted (placeholder)'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text('SUBMIT REQUEST'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(BuildContext context, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: label,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© 2026 BRIN Research Portal. All rights reserved.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Privacy Policy'),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Terms of Service'),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Support'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
