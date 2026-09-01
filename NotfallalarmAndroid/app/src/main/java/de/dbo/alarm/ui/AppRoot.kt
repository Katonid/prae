package de.dbo.alarm.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.core.net.toUri
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import de.dbo.alarm.R
import de.dbo.alarm.ui.alarm.AlarmScreen
import de.dbo.alarm.ui.alarm.AlarmViewModel
import de.dbo.alarm.ui.components.Banner
import de.dbo.alarm.ui.screens.AdminRoutes
import de.dbo.alarm.ui.screens.ChecklistScreen
import de.dbo.alarm.ui.screens.HomeScreen
import de.dbo.alarm.ui.screens.SettingsScreen
import de.dbo.alarm.ui.screens.SetupScreen
import de.dbo.alarm.ui.screens.TriggerScreen
import de.dbo.alarm.ui.screens.admin.AdminCodesScreen
import de.dbo.alarm.ui.screens.admin.AdminDevicesScreen
import de.dbo.alarm.ui.screens.admin.AdminHistoryScreen
import de.dbo.alarm.ui.screens.admin.AdminHomeScreen
import de.dbo.alarm.ui.screens.admin.AdminInstructionsScreen
import de.dbo.alarm.ui.screens.admin.AdminLocationsScreen
import de.dbo.alarm.ui.screens.admin.AdminViewModel

object Routes {
    const val SETUP = "setup"
    const val CHECKLIST_ONBOARDING = "checklist/onboarding"
    const val CHECKLIST = "checklist"
    const val HOME = "home"
    const val TRIGGER = "trigger"
    const val SETTINGS = "settings"
    const val ALARM = "alarm/{alarmId}"

    fun alarm(alarmId: String) = "alarm/$alarmId"
}

@Composable
fun AppRoot() {
    val session: SessionViewModel = viewModel()
    val state by session.state.collectAsState()
    val navController = rememberNavController()
    val context = LocalContext.current

    // Every entry of the checklist can be revoked from system settings while the app is in
    // the background, so the banner is re-derived each time the app comes forward again.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) session.refreshReadiness()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    if (!state.firebaseConfigured) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Banner(
                title = stringResource(R.string.firebase_missing_title),
                text = stringResource(R.string.firebase_missing_text),
            )
        }
        return
    }

    if (state.loading) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
        ) { Text(stringResource(R.string.loading), style = MaterialTheme.typography.bodyLarge) }
        return
    }

    val start = when {
        !state.hasGroup -> Routes.SETUP
        !state.onboardingDone -> Routes.CHECKLIST_ONBOARDING
        else -> Routes.HOME
    }

    NavHost(navController = navController, startDestination = start) {
        composable(Routes.SETUP) {
            SetupScreen(onDone = { navController.navigateClearing(Routes.CHECKLIST_ONBOARDING) })
        }

        composable(Routes.CHECKLIST_ONBOARDING) {
            ChecklistScreen(
                showFinishButton = true,
                onDone = {
                    session.finishOnboarding()
                    session.refreshReadiness()
                    navController.navigateClearing(Routes.HOME)
                },
            )
        }

        composable(Routes.CHECKLIST) {
            ChecklistScreen(
                showFinishButton = false,
                onDone = {
                    session.refreshReadiness()
                    navController.popBackStack()
                },
            )
        }

        composable(Routes.HOME) {
            HomeScreen(
                state = state,
                blockingReadinessCount = state.missingReadiness.count {
                    it != de.dbo.alarm.permissions.ReadinessItem.DND_ACCESS
                },
                onTrigger = { navController.navigate(Routes.TRIGGER) },
                onOpenAlarm = { navController.navigate(Routes.alarm(it)) },
                onOpenChecklist = { navController.navigate(Routes.CHECKLIST) },
                onOpenSettings = { navController.navigate(Routes.SETTINGS) },
                onOpenAdmin = { navController.navigate(AdminRoutes.HOME) },
                onOpenUpdate = { url -> openUrl(context, url) },
                onDismissUpdate = { session.dismissUpdate() },
            )
        }

        composable(Routes.TRIGGER) {
            TriggerScreen(
                state = state,
                onClose = { navController.popBackStack() },
                onOpenAlarm = {
                    navController.popBackStack()
                    navController.navigate(Routes.alarm(it))
                },
            )
        }

        composable(Routes.SETTINGS) {
            SettingsScreen(
                session = session,
                state = state,
                onBack = { navController.popBackStack() },
                onOpenChecklist = { navController.navigate(Routes.CHECKLIST) },
                onLeft = { navController.navigateClearing(Routes.SETUP) },
            )
        }

        composable(Routes.ALARM) { entry ->
            val alarmId = entry.arguments?.getString("alarmId").orEmpty()
            val groupId = state.groupId
            if (groupId != null && alarmId.isNotEmpty()) {
                val application = context.applicationContext as android.app.Application
                val viewModel: AlarmViewModel = viewModel(
                    key = "$groupId/$alarmId",
                    factory = AlarmViewModel.Factory(application, groupId, alarmId),
                )
                AlarmScreen(
                    viewModel = viewModel,
                    onClose = { navController.popBackStack() },
                    canGoBack = true,
                )
            }
        }

        adminGraph(navController, state) { session }
    }
}

private fun androidx.navigation.NavGraphBuilder.adminGraph(
    navController: NavHostController,
    state: SessionViewModel.State,
    @Suppress("UNUSED_PARAMETER") session: () -> SessionViewModel,
) {
    composable(AdminRoutes.HOME) {
        val admin: AdminViewModel = viewModel()
        AdminHomeScreen(
            state = state,
            viewModel = admin,
            onBack = { navController.popBackStack() },
            onDevices = { navController.navigate(AdminRoutes.DEVICES) },
            onCodes = { navController.navigate(AdminRoutes.CODES) },
            onLocations = { navController.navigate(AdminRoutes.LOCATIONS) },
            onInstructions = { navController.navigate(AdminRoutes.INSTRUCTIONS) },
            onHistory = { navController.navigate(AdminRoutes.HISTORY) },
            onOpenAlarm = { navController.navigate(Routes.alarm(it)) },
        )
    }
    composable(AdminRoutes.DEVICES) {
        AdminDevicesScreen(state = state, viewModel = viewModel(), onBack = { navController.popBackStack() })
    }
    composable(AdminRoutes.CODES) {
        AdminCodesScreen(state = state, viewModel = viewModel(), onBack = { navController.popBackStack() })
    }
    composable(AdminRoutes.LOCATIONS) {
        AdminLocationsScreen(state = state, viewModel = viewModel(), onBack = { navController.popBackStack() })
    }
    composable(AdminRoutes.INSTRUCTIONS) {
        AdminInstructionsScreen(state = state, viewModel = viewModel(), onBack = { navController.popBackStack() })
    }
    composable(AdminRoutes.HISTORY) {
        AdminHistoryScreen(
            viewModel = viewModel(),
            onBack = { navController.popBackStack() },
            onOpenAlarm = { navController.navigate(Routes.alarm(it)) },
        )
    }
}

private fun NavHostController.navigateClearing(route: String) {
    navigate(route) {
        popUpTo(graph.startDestinationId) { inclusive = true }
        launchSingleTop = true
    }
}

private fun openUrl(context: android.content.Context, url: String) {
    if (url.isBlank()) return
    runCatching {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, url.toUri()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }
}
