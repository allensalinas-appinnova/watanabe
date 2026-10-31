import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/planning_follow_up.dart';

abstract interface class PlanningFollowUpRepository {
  Stream<PlanningFollowUpSnapshot> watch(String userId);
  Future<Either<Failure, PlanningFollowUp?>> readCurrent(String userId, PlanningSource source);
  Future<Either<Failure, PlanningFollowUp>> mutate(String userId, PlanningFollowUpCommand command);
}
