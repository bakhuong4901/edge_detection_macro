package com.sample.edgedetection.crop

import android.app.Activity
import android.os.Bundle
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.ImageView
import com.sample.edgedetection.EdgeDetectionHandler
import com.sample.edgedetection.R
import com.sample.edgedetection.base.BaseActivity
import com.sample.edgedetection.view.PaperRectangle
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.*

class CropActivity : BaseActivity(), ICropView.Proxy {

    private var showMenuItems = false

    private lateinit var mPresenter: CropPresenter

    private lateinit var initialBundle: Bundle;

    private var checkCrop = false;

    override fun prepare() {
        this.initialBundle = intent.getBundleExtra(EdgeDetectionHandler.INITIAL_BUNDLE) as Bundle;
        this.title = initialBundle.getString(EdgeDetectionHandler.CROP_TITLE)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        findViewById<View>(R.id.paper).post {
            //we have to initialize everything in post when the view has been drawn and we have the actual height and width of the whole view
            mPresenter.onViewsReady(findViewById<View>(R.id.paper).width, findViewById<View>(R.id.paper).height)
        }
    }

    override fun provideContentViewId(): Int = R.layout.activity_crop


    override fun initPresenter() {
        val initialBundle = intent.getBundleExtra(EdgeDetectionHandler.INITIAL_BUNDLE) as Bundle;
        mPresenter = CropPresenter(this, this, initialBundle)
        findViewById<ImageView>(R.id.crop).setOnClickListener {
            Log.e(TAG, "Crop touched!")
            // Gọi hàm crop() bằng coroutine
            GlobalScope.launch(Dispatchers.Main) {
                val result = mPresenter.crop()
                if (result) {
                    Log.e(TAG, "Crop done!1")
                    mPresenter.save()
                    setResult(Activity.RESULT_OK)
                    System.gc()
                    finish()
                    // Thực hiện đoạn code khi crop() thành công
                } else {
                    // Thực hiện đoạn code khi crop() không thành công
                }
            }
        }
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {

        if (item.itemId == android.R.id.home) {
            onBackPressed()
            return true
        }

        return super.onOptionsItemSelected(item)
    }

    override fun getPaper(): ImageView = findViewById(R.id.paper)

    override fun getPaperRect(): PaperRectangle = findViewById<PaperRectangle>(R.id.paper_rect)

    override fun getCroppedPaper(): ImageView = findViewById<ImageView>(R.id.picture_cropped)

}
