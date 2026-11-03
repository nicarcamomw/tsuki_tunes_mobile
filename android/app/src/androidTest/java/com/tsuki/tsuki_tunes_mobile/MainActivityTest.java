package com.tsuki.tsuki_tunes_mobile;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

/**
 * Runs the Dart tests in integration_test/ as Android instrumentation tests,
 * which is how Firebase Test Lab runs them on its phones.
 */
@RunWith(FlutterTestRunner.class)
public class MainActivityTest {
  @Rule
  public ActivityTestRule<MainActivity> rule =
      new ActivityTestRule<>(MainActivity.class, true, false);
}
