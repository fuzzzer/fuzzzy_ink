package com.fuzzzycore.ink

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException

/**
 * Hands a file to the user: the system save dialog and the share sheet.
 *
 * The app keeps only sealed files, in its private storage; a plain file
 * exists only for one use, in the private hand-off folder (`files/handoff`),
 * and is wiped by the Dart side right after. Nothing is written to the
 * public Downloads folder or MediaStore, so nothing is indexed by a gallery.
 * The FileProvider serves the hand-off folder only (`res/xml/user_file_paths.xml`):
 * the store key, the vault and the sealed files are never reachable by URI.
 */
class UserFiles(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.fuzzzycore.ink/user_files"
        private const val HANDOFF_FOLDER = "handoff"
        private const val BINARY_MIME_TYPE = "application/octet-stream"
    }

    private val fileProviderAuthority get() = "${activity.packageName}.userfiles"
    private val mainThread = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "saveAs" -> saveAs(
                    path = call.argument<String>("path")!!,
                    fileName = call.argument<String>("fileName")!!,
                    mimeType = call.argument<String>("mimeType"),
                    result = result,
                )
                "shareFile" -> {
                    shareFile(call.argument<String>("path")!!, call.argument<String>("mimeType"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: FileNotFoundException) {
            result.error("notFound", e.message, null)
        } catch (e: ActivityNotFoundException) {
            result.error("noHandler", e.message, null)
        } catch (e: Exception) {
            result.error("failed", e.toString(), null)
        }
    }

    /** A `.fuzz` (or any unknown extension) travels as a plain binary so every target app accepts it. */
    private fun mimeTypeFor(displayName: String): String {
        val extension = displayName.substringAfterLast('.', "").lowercase()
        if (extension.isEmpty()) return BINARY_MIME_TYPE
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: BINARY_MIME_TYPE
    }

    // ---------------------------------------------------------------------
    // Save dialog
    // ---------------------------------------------------------------------

    /**
     * Shows the system save dialog (`ACTION_CREATE_DOCUMENT`) with [fileName]
     * proposed, then copies [path] — any file this app can read — to the
     * place the user picked, off the main thread. Answers `saved` or
     * `cancelled`; a copy that fails removes the half-written document.
     */
    private fun saveAs(path: String, fileName: String, mimeType: String?, result: MethodChannel.Result) {
        val source = File(path)
        if (!source.isFile) throw FileNotFoundException(path)
        val registry = (activity as ComponentActivity).activityResultRegistry
        val type = mimeType ?: mimeTypeFor(fileName)

        var launcher: ActivityResultLauncher<String>? = null
        launcher = registry.register(
            "user_files_save_${System.nanoTime()}",
            ActivityResultContracts.CreateDocument(type),
        ) { target: Uri? ->
            launcher?.unregister()
            if (target == null) {
                result.success("cancelled")
                return@register
            }
            Thread {
                try {
                    val resolver = activity.contentResolver
                    resolver.openOutputStream(target, "wt")!!.use { output ->
                        source.inputStream().use { input -> input.copyTo(output) }
                    }
                    mainThread.post { result.success("saved") }
                } catch (e: Exception) {
                    try {
                        DocumentsContract.deleteDocument(activity.contentResolver, target)
                    } catch (_: Exception) {
                    }
                    mainThread.post { result.error("failed", e.toString(), null) }
                }
            }.start()
        }
        launcher.launch(fileName)
    }

    // ---------------------------------------------------------------------
    // Share sheet
    // ---------------------------------------------------------------------

    /** Only a file inside the hand-off folder is shared; the Dart side copies anything else there first. */
    private fun shareFile(path: String, mimeType: String?) {
        val file = File(path)
        if (!file.isFile) throw FileNotFoundException(path)
        val handoff = File(activity.filesDir, HANDOFF_FOLDER).canonicalFile
        if (!file.canonicalPath.startsWith(handoff.path + File.separator)) {
            throw FileNotFoundException("$path is not in the hand-off folder")
        }

        val uri = FileProvider.getUriForFile(activity, fileProviderAuthority, file)
        val type = mimeType ?: mimeTypeFor(file.name)
        val send = Intent(Intent.ACTION_SEND)
            .setType(type)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // The grant must ride on the ClipData too, or a chooser target on
        // some OEM builds sees the URI without permission.
        send.clipData = ClipData.newUri(activity.contentResolver, file.name, uri)
        activity.startActivity(Intent.createChooser(send, null))
    }
}
