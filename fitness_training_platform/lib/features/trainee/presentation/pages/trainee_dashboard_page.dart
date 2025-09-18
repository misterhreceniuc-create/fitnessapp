import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../routing/route_names.dart';

class TraineeDashboardPage extends StatefulWidget {
  const TraineeDashboardPage({super.key});

  @override
  State<TraineeDashboardPage> createState() => _TraineeDashboardPageState();
}

class _TraineeDashboardPageState extends State<TraineeDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome ${currentUser?.name ?? 'User'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _showNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center), text: 'Workouts'),
            Tab(icon: Icon(Icons.restaurant), text: 'Nutrition'),
            Tab(icon: Icon(Icons.trending_up), text: 'Goals'),
            Tab(icon: Icon(Icons.analytics), text: 'Progress'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWorkoutsTab(),
          _buildNutritionTab(),
          _buildGoalsTab(),
          _buildProgressTab(),
        ],
      ),
    );
  }

  Widget _buildWorkoutsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your trainer will assign workouts that will appear here.',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: 3, // Mock workouts
              itemBuilder: (context, index) {
                final workouts = ['Upper Body Strength', 'Cardio Session', 'Lower Body Power'];
                final isCompleted = index == 0; // First workout is completed
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCompleted ? Colors.green : Colors.orange,
                      child: Icon(
                        isCompleted ? Icons.check : Icons.fitness_center,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      workouts[index],
                      style: TextStyle(
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      isCompleted ? 'Completed yesterday' : 'Scheduled for today',
                      style: TextStyle(
                        color: isCompleted ? Colors.green : Colors.orange,
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: isCompleted ? null : () => _startWorkout(workouts[index]),
                      child: Text(isCompleted ? 'Done' : 'Start'),
                    ),
                    onTap: () => _viewWorkoutDetails(workouts[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Today\'s Calories',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '1,250 / 2,000',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 1250 / 2000,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _logFood,
                  icon: const Icon(Icons.add),
                  label: const Text('Log Food'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _viewMealPlan,
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Meal Plan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildMealCard('Breakfast', '🥞', '450 cal', true),
                _buildMealCard('Lunch', '🥗', '600 cal', true),
                _buildMealCard('Snack', '🍎', '200 cal', true),
                _buildMealCard('Dinner', '🍽️', '800 cal', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(String meal, String emoji, String calories, bool logged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 24)),
        title: Text(meal),
        subtitle: Text(logged ? 'Logged: $calories' : 'Not logged yet'),
        trailing: logged
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(
                onPressed: () => _logMeal(meal),
                child: const Text('Log'),
              ),
      ),
    );
  }

  Widget _buildGoalsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildGoalCard(
            'Weight Loss',
            'Target: 70 kg',
            'Current: 75 kg',
            5 / 5, // Progress: 5kg lost out of 5kg target
            Colors.blue,
            Icons.monitor_weight,
          ),
          _buildGoalCard(
            'Bench Press',
            'Target: 80 kg',
            'Current: 65 kg',
            15 / 15, // Progress: 15kg increase out of 15kg target
            Colors.orange,
            Icons.fitness_center,
          ),
          _buildGoalCard(
            'Weekly Workouts',
            'Target: 4 workouts/week',
            'This week: 3 completed',
            3 / 4,
            Colors.green,
            Icons.calendar_today,
          ),
          _buildGoalCard(
            '5K Run Time',
            'Target: 25:00',
            'Current: 28:30',
            (28.5 - 25) / (30 - 25), // Progress towards target
            Colors.purple,
            Icons.directions_run,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(String title, String target, String current, double progress, Color color, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(target),
            Text(current, style: TextStyle(color: color)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).clamp(0, 100).toInt()}% Complete',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('Workouts', '12', 'This month', Icons.fitness_center, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Weight', '-2.5kg', 'Lost', Icons.trending_down, Colors.green)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard('Calories', '1,250', 'Today', Icons.local_fire_department, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Streak', '7 days', 'Active', Icons.whatshot, Colors.red)),
            ],
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Progress Charts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Detailed charts would be displayed here'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Action methods
  void _startWorkout(String workout) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start $workout'),
        content: const Text('Ready to begin your workout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$workout started! 💪')),
              );
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _viewWorkoutDetails(String workout) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(workout),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Push-ups: 3 sets x 15 reps'),
            Text('• Squats: 3 sets x 20 reps'),
            Text('• Plank: 3 sets x 60 seconds'),
            Text('• Burpees: 3 sets x 10 reps'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _logFood() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Food logging feature - coming soon!')),
    );
  }

  void _viewMealPlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Today\'s Meal Plan'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🥞 Breakfast: Oatmeal with fruits (450 cal)'),
            Text('🥗 Lunch: Grilled chicken salad (600 cal)'),
            Text('🍎 Snack: Apple and almonds (200 cal)'),
            Text('🍽️ Dinner: Salmon with vegetables (800 cal)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _logMeal(String meal) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$meal logged successfully! 🍽️')),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.fitness_center, color: Colors.blue),
              title: Text('New workout assigned'),
              subtitle: Text('Upper Body Strength - Today'),
            ),
            ListTile(
              leading: Icon(Icons.restaurant, color: Colors.orange),
              title: Text('Meal plan updated'),
              subtitle: Text('Check your new nutrition goals'),
            ),
            ListTile(
              leading: Icon(Icons.celebration, color: Colors.green),
              title: Text('Goal achieved!'),
              subtitle: Text('You reached your weight loss target'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
              context.go(RouteNames.login);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}