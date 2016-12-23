package io.skyway.testpeerjava;

import io.skyway.Peer.*;
import io.skyway.Peer.Browser.*;

//import io.skyway.Peer.Browser.Canvas;
//import io.skyway.Peer.Browser.MediaConstraints;
//import io.skyway.Peer.Browser.MediaStream;
//import io.skyway.Peer.Browser.Navigator;
//import io.skyway.Peer.DataConnection;
//import io.skyway.Peer.ConnectOption;
//import io.skyway.Peer.DataConnection;
//import io.skyway.Peer.MediaConnection;
//import io.skyway.Peer.OnCallback;
//import io.skyway.Peer.Peer;
//import io.skyway.Peer.PeerError;
//import io.skyway.Peer.PeerOption;

import android.Manifest;
import android.app.Activity;
import android.app.FragmentManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.AudioManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;


/**
 *
 */
public class MediaActivity
		extends Activity
{
	private static final String TAG =MediaActivity.class.getSimpleName();

	private Peer            _peer;
	private DataConnection  _dataconn;
	private MediaConnection _mediaconnVideo;
	private MediaConnection _mediaconnAudio;

	private MediaStream _msLocal;
	private MediaStream _msRemote;

	private Handler _handler;

	private String   _id;
	private String[] _listPeerIds;
	private String _remoteId;
	private boolean  _bDataConnected;
	private boolean  _bAudioConnected;

	@Override
	protected void onCreate(Bundle savedInstanceState)
	{
		super.onCreate(savedInstanceState);

		Window wnd = getWindow();
		wnd.addFlags(Window.FEATURE_NO_TITLE);

		setContentView(R.layout.activity_video_chat);

		_handler = new Handler(Looper.getMainLooper());
		Context context = getApplicationContext();


		PeerOption options = new PeerOption();

		//Enter your API Key.
		options.key = "";
		//Enter your registered Domain.
		options.domain = "";

		_peer = new Peer(context, options);
		setPeerCallback(_peer);

		if (ContextCompat.checkSelfPermission(this,
                Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED && ContextCompat.checkSelfPermission(this,
                Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED){
                ActivityCompat.requestPermissions(this,new String[]{Manifest.permission.CAMERA,Manifest.permission.RECORD_AUDIO},0);
            }else{
            startLocalStream();
        }


		_bDataConnected = false;


		//
		// Initialize views
		//
		Button btnAction = (Button) findViewById(R.id.btnAction);
		btnAction.setEnabled(true);
		btnAction.setOnClickListener(new View.OnClickListener()
		{
			@Override
			public void onClick(View v)
			{
				v.setEnabled(false);

				if (!_bDataConnected)
				{
					listingPeers();
				}
				else
				{
					closeConnection();
				}

				v.setEnabled(true);
			}
		});

		//
		Button startSoundButton = (Button)findViewById(R.id.startSoundButton);
		startSoundButton.setOnClickListener(new View.OnClickListener()
		{
			@Override
			public void onClick(View v)
			{
				if(!_bAudioConnected){
					Log.d(TAG, "start to send voice");
					_mediaconnAudio = _peer.call(_remoteId,_msLocal);
					setMediaCallback(_mediaconnAudio);
					_bAudioConnected = true;
				}else{
					//音声接続を切断
					Log.d(TAG, "stop to send voice");
					if(_mediaconnAudio != null){
						_mediaconnAudio.close();
						_bAudioConnected = false;
					}
				}

				updateUI();

			}
		});

	}




    @Override
    public void onRequestPermissionsResult(int requestCode, String permissions[], int[] grantResults) {
        switch (requestCode) {
            case 0: {
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    startLocalStream();
                }else{
                    Toast.makeText(this,"Failed to access the camera and microphone.\nclick allow when asked for permission.",Toast.LENGTH_LONG).show();
                }
                break;
            }
        }
    }

    void startLocalStream(){
        Navigator.initialize(_peer);
        MediaConstraints constraints = new MediaConstraints();
		constraints.videoFlag = false;
		constraints.audioFlag = true;
		Log.d(TAG, "start audio only getUserMedia");
        _msLocal = Navigator.getUserMedia(constraints);
    }



	//strPeerId:listDialogで選択されたPeerID
	void calling(String strPeerId)
	{

		if (null == _peer)
		{
			return;
		}

		ConnectOption option = new ConnectOption();
		option.serialization = DataConnection.SerializationEnum.NONE;

		_dataconn = _peer.connect(strPeerId,option);
		_remoteId = strPeerId;
		setDataCallback(_dataconn);

		updateUI();
	}

	void setDataCallback(DataConnection data)
	{
		data.on(DataConnection.DataEventEnum.OPEN, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				//OPENしたので、ビデオのSTREAMを要求SSG:stream/start
				Log.d(TAG, "onCallback: DataEvent OPEN");

				String str = "SSG:stream/start," + _id;

				Log.d(TAG, "attempt to send message ... " + str);

				_dataconn.send(str);
			}
		});

		data.on(DataConnection.DataEventEnum.DATA, new OnCallback() {
			@Override
			public void onCallback(Object object) {
				String receivedData;

				if (object instanceof String) {
					receivedData = (String) object;
					Log.d(TAG, "data received: "+receivedData);
				}
					updateUI();
			}
		});

		data.on(DataConnection.DataEventEnum.CLOSE, new OnCallback() {
			@Override
			public void onCallback(Object object) {
				Log.d(TAG, "DataEvent Close");
			}
		});

		data.on(DataConnection.DataEventEnum.ERROR, new OnCallback() {
			@Override
			public void onCallback(Object object) {
				// TODO: DataEvent/ERROR
				PeerError error = (PeerError) object;

				String strMessage = error.message;
				String strLabel = getString(android.R.string.ok);

				MessageDialogFragment dialog = new MessageDialogFragment();
				dialog.setPositiveLabel(strLabel);
				dialog.setMessage(strMessage);

				dialog.show(getFragmentManager(), "error");
			}
		});
	}



	//////////Start:Set Peer callback////////////////
	////////////////////////////////////////////////
	private void setPeerCallback(Peer peer)
	{

		peer.on(Peer.PeerEventEnum.OPEN, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				Log.d(TAG, "[On/Open]");

				if (object instanceof String)
				{
					_id = (String) object;
					Log.d(TAG, "ID:" + _id);

					updateUI();
				}
			}
		});

		peer.on(Peer.PeerEventEnum.CALL, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				Log.d(TAG, "[On/Call]");
				if (!(object instanceof MediaConnection))
				{
					return;
				}

				_mediaconnVideo = (MediaConnection) object;
				_mediaconnVideo.answer(null);
				setMediaCallback(_mediaconnVideo);


				updateUI();
			}
		});

		peer.on(Peer.PeerEventEnum.CONNECTION, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				Log.d(TAG, "[Peer.PeerEventEnum.CONNECTION]");

				_mediaconnVideo = (MediaConnection) object;
				_mediaconnVideo.answer(null);
				setMediaCallback(_mediaconnVideo);

				_bDataConnected = true;

				updateUI();
			}
		});

		peer.on(Peer.PeerEventEnum.CLOSE, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				Log.d(TAG, "[On/Close]");
			}
		});

		// !!!: Event/Disconnected
		peer.on(Peer.PeerEventEnum.DISCONNECTED, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				Log.d(TAG, "[On/Disconnected]");
			}
		});

		// !!!: Event/Error
		peer.on(Peer.PeerEventEnum.ERROR, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				PeerError error = (PeerError) object;

				Log.d(TAG, "[On/Error]" + error);

				String strMessage = "" + error;
				String strLabel = getString(android.R.string.ok);

				MessageDialogFragment dialog = new MessageDialogFragment();
				dialog.setPositiveLabel(strLabel);
				dialog.setMessage(strMessage);

				dialog.show(getFragmentManager(), "error");
			}
		});

	}


	void setMediaCallback(MediaConnection media)
	{
		media.on(MediaConnection.MediaEventEnum.STREAM, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				_msRemote = (MediaStream) object;

				Canvas canvas = (Canvas) findViewById(R.id.svPrimary);
				canvas.addSrc(_msRemote, 0);
			}
		});

		media.on(MediaConnection.MediaEventEnum.CLOSE, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				if (null == _msRemote)
				{
					return;
				}

				Canvas canvas = (Canvas) findViewById(R.id.svPrimary);
				canvas.removeSrc(_msRemote, 0);

				updateUI();
			}
		});

		media.on(MediaConnection.MediaEventEnum.ERROR, new OnCallback()
		{
			@Override
			public void onCallback(Object object)
			{
				PeerError error = (PeerError) object;

				Log.d(TAG, "[On/MediaError]" + error);

				String strMessage = "" + error;
				String strLabel = getString(android.R.string.ok);

				MessageDialogFragment dialog = new MessageDialogFragment();
				dialog.setPositiveLabel(strLabel);
				dialog.setMessage(strMessage);

				dialog.show(getFragmentManager(), "error");
			}
		});
	}


	// Listing all peers
	void listingPeers()
	{
		if ((null == _peer) || (null == _id) || (0 == _id.length()))
		{
			return;
		}

		_peer.listAllPeers(new OnCallback() {
			@Override
			public void onCallback(Object object) {
				if (!(object instanceof JSONArray)) {
					return;
				}

				JSONArray peers = (JSONArray) object;

				StringBuilder sbItems = new StringBuilder();
				for (int i = 0; peers.length() > i; i++) {
					String strValue = "";
					try {
						strValue = peers.getString(i);
					} catch (Exception e) {
						e.printStackTrace();
					}

					if (0 == _id.compareToIgnoreCase(strValue)) {
						continue;
					}

					if (0 < sbItems.length()) {
						sbItems.append(",");
					}

					sbItems.append(strValue);
				}

				String strItems = sbItems.toString();
				_listPeerIds = strItems.split(",");

				if ((null != _listPeerIds) && (0 < _listPeerIds.length)) {
					selectingPeer();
				}
			}
		});

	}

	/**
	 * Selecting peer
	 */
	void selectingPeer()
	{
		if (null == _handler)
		{
			return;
		}

		_handler.post(new Runnable() {
			@Override
			public void run() {
				FragmentManager mgr = getFragmentManager();

				PeerListDialogFragment dialog = new PeerListDialogFragment();
				dialog.setListener(
						new PeerListDialogFragment.PeerListDialogFragmentListener() {
							@Override
							public void onItemClick(final String item) {

								_handler.post(new Runnable() {
									@Override
									public void run() {
										calling(item);
									}
								});
							}
						});
				dialog.setItems(_listPeerIds);

				dialog.show(mgr, "peerlist");
			}
		});
	}



	/**
	 * Closing connection.
	 */
	void closeConnection()
	{
		if(_mediaconnVideo != null){
			unsetMediaCallback(_mediaconnVideo);
			_mediaconnVideo.close();
		}
		if(_mediaconnAudio != null){
			unsetMediaCallback(_mediaconnAudio);
			_mediaconnAudio.close();
		}
		if(_dataconn != null){
			unsetDataCallback(_dataconn);
			_dataconn.close();
		}

		_bAudioConnected = false;
		_bDataConnected = false;

		_mediaconnVideo = null;
		_mediaconnAudio = null;
		_dataconn = null;

	}


	void unsetMediaCallback(MediaConnection media) {
		media.on(MediaConnection.MediaEventEnum.STREAM, null);
		media.on(MediaConnection.MediaEventEnum.CLOSE, null);
		media.on(MediaConnection.MediaEventEnum.ERROR, null);
	}

	void unsetDataCallback(DataConnection data) {
		data.on(DataConnection.DataEventEnum.OPEN,null);
		data.on(DataConnection.DataEventEnum.CLOSE,null);
		data.on(DataConnection.DataEventEnum.DATA,null);
		data.on(DataConnection.DataEventEnum.ERROR,null);
	}

	void unsetPeerCallback(Peer peer){
		peer.on(Peer.PeerEventEnum.OPEN,null);
		peer.on(Peer.PeerEventEnum.CONNECTION,null);
		peer.on(Peer.PeerEventEnum.CALL,null);
		peer.on(Peer.PeerEventEnum.CLOSE,null);
		peer.on(Peer.PeerEventEnum.DISCONNECTED,null);
		peer.on(Peer.PeerEventEnum.ERROR,null);
	}


	void updateUI()
	{
		_handler.post(new Runnable() {
			@Override
			public void run() {
				Button btnAction = (Button) findViewById(R.id.btnAction);
				if (null != btnAction) {
					if (false == _bDataConnected) {
						btnAction.setText("CONNECT");
					} else {
						btnAction.setText("DISCONNECT");
					}
				}

				Button btnSound = (Button) findViewById(R.id.startSoundButton);
				if (null != btnSound) {
					if (false == _bAudioConnected) {
						btnSound.setText("start sound");
					} else {
						btnSound.setText("stop sound");
					}
				}

				TextView tvOwnId = (TextView) findViewById(R.id.tvOwnId);
				if (null != tvOwnId) {
					if (null == _id) {
						tvOwnId.setText("");
					} else {
						tvOwnId.setText(_id);
					}
				}
			}
		});
	}


	/**
	 * Destroy Peer object.
	 */
	private void destroyPeer()
	{
		closeConnection();

		if (null != _msRemote)
		{
			Canvas canvas = (Canvas) findViewById(R.id.svPrimary);
			canvas.removeSrc(_msRemote, 0);

			_msRemote.close();

			_msRemote = null;
		}

		if (null != _msLocal)
		{
			Canvas canvas = (Canvas) findViewById(R.id.svSecondary);
			canvas.removeSrc(_msLocal, 0);

			_msLocal.close();

			_msLocal = null;
		}

		Navigator.terminate();

		if (null != _peer)
		{
			unsetPeerCallback(_peer);

			if (false == _peer.isDisconnected)
			{
				_peer.disconnect();
			}

			if (false == _peer.isDestroyed)
			{
				_peer.destroy();
			}

			_peer = null;
		}
	}



	@Override
	protected void onStart()
	{
		super.onStart();

		// Disable Sleep and Screen Lock
		Window wnd = getWindow();
		wnd.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
		wnd.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
	}

	@Override
	protected void onResume()
	{
		super.onResume();

		// Set volume control stream type to WebRTC audio.
		setVolumeControlStream(AudioManager.STREAM_VOICE_CALL);
	}

	@Override
	protected void onPause()
	{
		// Set default volume control stream type.
		setVolumeControlStream(AudioManager.USE_DEFAULT_STREAM_TYPE);

		super.onPause();
	}

	@Override
	protected void onStop()
	{
		// Enable Sleep and Screen Lock
		Window wnd = getWindow();
		wnd.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
		wnd.clearFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);

		super.onStop();
	}

	@Override
	protected void onDestroy()
	{
		destroyPeer();

		_listPeerIds = null;
		_handler = null;

		super.onDestroy();
	}

}
