package com.sample.edgedetection.crop

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Bundle
import android.util.Log
import android.view.View
import com.sample.edgedetection.EdgeDetectionHandler
import com.sample.edgedetection.SourceManager
import com.sample.edgedetection.processor.Corners
import com.sample.edgedetection.processor.TAG
import com.sample.edgedetection.processor.cropPicture
import com.sample.edgedetection.processor.enhancePicture
import io.reactivex.Observable
import io.reactivex.android.schedulers.AndroidSchedulers
import io.reactivex.schedulers.Schedulers
import org.opencv.android.Utils
import org.opencv.core.Mat
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.*


const val IMAGES_DIR = "smart_scanner"

class CropPresenter(
    private val context: Context,
    private val iCropView: ICropView.Proxy,
    private val initialBundle: Bundle
) {
    private val picture: Mat? = SourceManager.pic

    private val corners: Corners? = SourceManager.corners
    private var croppedPicture: Mat? = null
    private var enhancedPicture: Bitmap? = null
    private var croppedBitmap: Bitmap? = null
    private var rotateBitmap: Bitmap? = null
    private var rotateBitmapDegree: Int = -90

    fun onViewsReady(paperWidth: Int, paperHeight: Int) {
        iCropView.getPaperRect().onCorners2Crop(corners, picture?.size(), paperWidth, paperHeight)
        val bitmap = Bitmap.createBitmap(
            picture?.width() ?: 1080, picture?.height()
                ?: 1920, Bitmap.Config.ARGB_8888
        )
        Utils.matToBitmap(picture, bitmap, true)
        iCropView.getPaper().setImageBitmap(bitmap)
    }

    // Khai báo hàm crop() với suspend modifier để sử dụng coroutine
    suspend fun crop(): Boolean {
        if (picture == null) {
            Log.i(TAG, "picture null?")
            return false
        }

        if (croppedBitmap != null) {
            Log.i(TAG, "already cropped")
            return false
        }

        val pc = withContext(Dispatchers.Default) {
            cropPicture(picture, iCropView.getPaperRect().getCorners2Crop())
        }

        Log.i(TAG, "cropped picture: $pc")
        croppedPicture = pc
        croppedBitmap =
                Bitmap.createBitmap(pc.width(), pc.height(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(pc, croppedBitmap)
        //iCropView.getCroppedPaper().setImageBitmap(croppedBitmap)
        //iCropView.getPaper().visibility = View.GONE
        //iCropView.getPaperRect().visibility = View.GONE

        return true
    }
    
    fun save() {
        val file = File(initialBundle.getString(EdgeDetectionHandler.SAVE_TO) as String);

        val cropPic = croppedBitmap
        if (null != cropPic) {
            val outStream = FileOutputStream(file)
            cropPic.compress(Bitmap.CompressFormat.JPEG, 100, outStream)
            outStream.flush()
            outStream.close()
            cropPic.recycle()
            Log.i(TAG, "CroppedBitmap Saved")
        }
    }

    fun Bitmap.rotateFloat(degrees: Float): Bitmap {
        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
    }

    // Extension function to rotate a bitmap
    private fun Bitmap.rotateInt(degree: Int): Bitmap {
        // Initialize a new matrix
        val matrix = Matrix()

        // Rotate the bitmap
        matrix.postRotate(degree.toFloat())

        // Resize the bitmap
        val scaledBitmap = Bitmap.createScaledBitmap(
            this,
            width,
            height,
            true
        )

        // Create and return the rotated bitmap
        return Bitmap.createBitmap(
            scaledBitmap,
            0,
            0,
            scaledBitmap.width,
            scaledBitmap.height,
            matrix,
            true
        )
    }
}
