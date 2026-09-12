package com.devaccess.app.report

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream

/**
 * FR-REP-2 / FR-REP-3 — share sheet, clipboard (handled in Dart) and Storage Access
 * Framework saves, plus the PDF renderer.
 *
 * Nothing here transmits anything: exports are local files and an explicit share intent
 * chosen by the user (NFR-PRIV-1).
 */
object Exporter {

    const val REQUEST_CREATE_DOCUMENT = 7301

    private var pendingBytes: ByteArray? = null

    /** Builds the SAF picker intent and stashes the payload until the result arrives. */
    fun beginSave(activity: Activity, name: String, mime: String, bytes: ByteArray): Boolean = try {
        pendingBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mime)
            .putExtra(Intent.EXTRA_TITLE, name)
        activity.startActivityForResult(intent, REQUEST_CREATE_DOCUMENT)
        true
    } catch (t: Throwable) {
        pendingBytes = null
        false
    }

    /** Called from MainActivity.onActivityResult. Returns the outcome for the Dart caller. */
    fun finishSave(context: Context, resultCode: Int, data: Intent?): Map<String, Any?> {
        val bytes = pendingBytes
        pendingBytes = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            return mapOf("ok" to false, "cancelled" to true)
        }
        if (bytes == null) return mapOf("ok" to false, "error" to "No pending export payload")
        return try {
            context.contentResolver.openOutputStream(data.data!!, "wt")?.use { it.write(bytes) }
                ?: return mapOf("ok" to false, "error" to "Could not open the chosen file for writing")
            mapOf("ok" to true, "uri" to data.data.toString(), "bytes" to bytes.size)
        } catch (t: Throwable) {
            mapOf("ok" to false, "error" to "${t.javaClass.simpleName}: ${t.message}")
        }
    }

    fun shareText(context: Context, text: String, subject: String?, chooserTitle: String): Map<String, Any?> = try {
        val intent = Intent(Intent.ACTION_SEND)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT, text)
        subject?.let { intent.putExtra(Intent.EXTRA_SUBJECT, it) }
        val chooser = Intent.createChooser(intent, chooserTitle)
        if (context !is Activity) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooser)
        mapOf("ok" to true)
    } catch (t: Throwable) {
        mapOf("ok" to false, "error" to "${t.javaClass.simpleName}: ${t.message}")
    }

    /** Shares a generated file through the app's FileProvider so no storage permission is needed. */
    fun shareFile(
        context: Context,
        name: String,
        mime: String,
        bytes: ByteArray,
        subject: String?,
        chooserTitle: String,
    ): Map<String, Any?> = try {
        val dir = File(context.cacheDir, "exports").apply { mkdirs() }
        val file = File(dir, name)
        FileOutputStream(file).use { it.write(bytes) }
        val uri: Uri = FileProvider.getUriForFile(
            context, "${context.packageName}.fileprovider", file,
        )
        val intent = Intent(Intent.ACTION_SEND)
            .setType(mime)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        subject?.let { intent.putExtra(Intent.EXTRA_SUBJECT, it) }
        val chooser = Intent.createChooser(intent, chooserTitle)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        if (context !is Activity) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooser)
        mapOf("ok" to true, "uri" to uri.toString())
    } catch (t: Throwable) {
        mapOf("ok" to false, "error" to "${t.javaClass.simpleName}: ${t.message}")
    }

    /**
     * FR-REP-2 (stretch) — renders the plain-text report to A4 pages with [PdfDocument].
     * Monospaced so column-aligned key/value lines survive.
     */
    fun renderPdf(title: String, body: String): ByteArray {
        val pageWidth = 595   // A4 @ 72dpi
        val pageHeight = 842
        val margin = 40f
        val doc = PdfDocument()

        val titlePaint = Paint().apply {
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            textSize = 13f
            isAntiAlias = true
        }
        val bodyPaint = Paint().apply {
            typeface = Typeface.MONOSPACE
            textSize = 8.5f
            isAntiAlias = true
        }
        val footerPaint = Paint().apply {
            typeface = Typeface.MONOSPACE
            textSize = 7f
            color = 0xFF888888.toInt()
            isAntiAlias = true
        }

        val lineHeight = bodyPaint.fontSpacing
        val usableWidth = pageWidth - margin * 2
        val maxChars = (usableWidth / bodyPaint.measureText("M")).toInt().coerceAtLeast(20)

        // Hard-wrap on character count: monospace makes this exact.
        val lines = body.lines().flatMap { raw ->
            if (raw.length <= maxChars) listOf(raw)
            else raw.chunked(maxChars)
        }

        var index = 0
        var pageNumber = 1
        while (index < lines.size || pageNumber == 1) {
            val page = doc.startPage(
                PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create(),
            )
            val canvas = page.canvas
            var y = margin + titlePaint.fontSpacing
            if (pageNumber == 1) {
                canvas.drawText(title, margin, y, titlePaint)
                y += titlePaint.fontSpacing
            }
            while (index < lines.size && y + lineHeight < pageHeight - margin) {
                canvas.drawText(lines[index], margin, y, bodyPaint)
                y += lineHeight
                index++
            }
            canvas.drawText(
                "DevAccess — page $pageNumber", margin, (pageHeight - margin / 2), footerPaint,
            )
            doc.finishPage(page)
            pageNumber++
            if (index >= lines.size) break
        }

        return java.io.ByteArrayOutputStream().use { out ->
            doc.writeTo(out)
            doc.close()
            out.toByteArray()
        }
    }
}
