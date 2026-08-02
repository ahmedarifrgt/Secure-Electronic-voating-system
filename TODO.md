# Secure Electronic Voting System — Frontend Redesign & Integration TODO

## Phase A — Foundation
- [ ] A1. Update `pubspec.yaml` (add provider, shared_preferences)
- [ ] A2. Create `lib/core/palette.dart` (shared design tokens)
- [ ] A3. Create `lib/core/api_client.dart` (centralized HTTP + JWT)

## Phase B — Data Models
- [ ] B1. Create `lib/models/voter.dart`
- [ ] B2. Create `lib/models/election.dart`
- [ ] B3. Create `lib/models/candidate.dart`
- [ ] B4. Create `lib/models/dashboard_stats.dart`
- [ ] B5. Create `lib/models/vote_result.dart`

## Phase C — State Management (Providers)
- [ ] C1. Create `lib/providers/auth_provider.dart`
- [ ] C2. Create `lib/providers/election_provider.dart`
- [ ] C3. Create `lib/providers/dashboard_provider.dart`

## Phase D — Shared Widgets
- [ ] D1. Create `lib/widgets/loading_overlay.dart`
- [ ] D2. Create `lib/widgets/stat_card.dart`
- [ ] D3. Create `lib/widgets/election_card.dart`
- [ ] D4. Create `lib/widgets/candidate_card.dart`

## Phase E — Screens
- [ ] E1. Update `lib/main.dart` (MultiProvider + theme)
- [ ] E2. Create `lib/screens/login/login_screen.dart` (AuthProvider integration)
- [ ] E3. Rewrite `lib/screens/dashboard/admin_dashboard.dart`
- [ ] E4. Rewrite `lib/screens/election/election_screen.dart`
- [ ] E5. Create `lib/screens/election/candidate_selection_screen.dart`
- [ ] E6. Rewrite `lib/screens/voting/vote_confirmation_screen.dart`
- [ ] E7. Create `lib/screens/voting/vote_success_screen.dart`
- [ ] E8. Rewrite `lib/screens/reports/results_screen.dart`

## Phase F — Verification
- [ ] F1. Run `flutter analyze`
- [ ] F2. Verify UI flows against backend API

