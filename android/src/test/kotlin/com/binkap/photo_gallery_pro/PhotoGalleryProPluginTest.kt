package com.binkap.photo_gallery_pro

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertNotSame
import org.mockito.Mockito
import java.util.concurrent.atomic.AtomicReference

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class PhotoGalleryProPluginTest {
  @Test
  fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
    val plugin = PhotoGalleryProPlugin()

    val call = MethodCall("getPlatformVersion", null)
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.SDK_INT)
  }

  @Test
  fun onMethodCall_getThumbnail_runsOnBackgroundThread() {
    val plugin = PhotoGalleryProPlugin()
    val callingThread = Thread.currentThread()
    val resultThread = AtomicReference<Thread>()
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

    Mockito.doAnswer {
      resultThread.set(Thread.currentThread())
      null
    }.`when`(mockResult).error(
      Mockito.anyString(),
      Mockito.anyString(),
      Mockito.isNull()
    )

    plugin.onMethodCall(
      MethodCall(
        "getThumbnail",
        mapOf("mediaId" to "1", "mediaType" to "unsupported")
      ),
      mockResult
    )

    Mockito.verify(mockResult, Mockito.timeout(1000)).error(
      Mockito.anyString(),
      Mockito.anyString(),
      Mockito.isNull()
    )
    assertNotSame(callingThread, resultThread.get())
  }
}
