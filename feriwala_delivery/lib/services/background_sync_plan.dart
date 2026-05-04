/// Background sync rollout notes for delivery app.
///
/// Phase 1 (current): foreground polling + lifecycle resume refresh + offline queue replay.
/// Phase 2: integrate platform background workers to run queue replay and location sync.
/// - Android: WorkManager periodic work
/// - iOS: BGTaskScheduler app refresh task
///
/// This placeholder keeps the strategy documented near services until platform-specific
/// implementation is introduced in dedicated files.
class BackgroundSyncPlan {
  static const bool platformBackgroundSyncEnabled = false;
}
