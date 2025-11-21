import 'package:boot_helper/misc/logger.dart';

import 'package:boot_helper/DB/supabase_db.dart';
import 'package:boot_helper/Projects/Project.dart';

class ProjectService {
  static Future<List<Project>> getProjects(String userID) async {
    final response = await SupabaseDB.getMultipleRowData(
      table: 'projects',
      column: 'owner',
      columnValue: [userID],
    );
    if (response.isEmpty) return [];
    return response.map<Project>((row) => Project.fromRow(row)).toList();
  }

  static Future<Project?> getProjectById(int projectId) async {
    try {
      final response = await SupabaseDB.getRowData(
        table: 'projects',
        rowID: projectId,
      );
      return Project.fromRow(response);
    } catch (e, stack) {
      AppLogger.error('Error fetching project by ID $projectId', e, stack);
      return null;
    }
  }
}
