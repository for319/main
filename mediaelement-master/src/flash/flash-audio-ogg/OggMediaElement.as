package {
	import flash.display.LoaderInfo;
	import flash.display.Sprite;

	import flash.events.*;
	import flash.external.*;
	import flash.system.*;

	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;

	import com.automatastudios.audio.audiodecoder.AudioDecoder;
	import com.automatastudios.audio.audiodecoder.decoders.*;

	import flash.net.URLStream;
	import flash.net.URLRequest;
	import flash.utils.Timer;

	public class OggMediaElement extends Sprite {
		
		private var _isLoaded:Boolean = false;
		private var _isPlaying:Boolean = false;
		private var _playWhenLoaded:Boolean = false;
		private var _isEnded:Boolean = false;
		private var _autoplay:Boolean = false;

		private var _src:String = '';
		private var _volume:Number = 1;
		private var _currentTime:Number = 0;
		private var _duration:Number = 0;
		private var _readyState:Number = 0;

		private var _timer:Timer;
		private var _id:String;

		private var _urlRequest:URLRequest;
		private var _urlStream:URLStream;
		private var _decoder:AudioDecoder;

		private var _sound:Sound = null;
		private var _channel:SoundChannel;
		private var _transform:SoundTransform = new SoundTransform(1, 0);

		/**
		 * @constructor
		 */
		public function OggMediaElement() {

			if (isIllegalQuerystring()) {
				return;
			}

			var flashVars:Object = LoaderInfo(this.root.loaderInfo).parameters;

			// Use this for CDN
			if (flashVars.allowScriptAccess == 'always') {
				Security.allowDomain(['*']);
				Security.allowInsecureDomain(['*']);
			}

			_id = flashVars.uid;
			_autoplay = (flashVars.autoplay == true);

			_timer = new Timer(250);
			_timer.addEventListener(TimerEvent.TIMER, timerHander);

			_urlStream = new URLStream();
			_urlRequest = null;

			_decoder = new AudioDecoder();
			_decoder.load(_urlStream, OggVorbisDecoder, 8000);
			_decoder.addEventListener(Event.INIT, onDecoderInit);
			_decoder.addEventListener(Event.COMPLETE, onSoundComplete);
			_decoder.addEventListener(IOErrorEvent.IO_ERROR, onIOError);

			ExternalInterface.addCallback('get_src', get_src);
			ExternalInterface.addCallback('get_paused', get_paused);
			ExternalInterface.addCallback('get_volume',get_volume);
			ExternalInterface.addCallback('get_currentTime', get_currentTime);
			ExternalInterface.addCallback('get_duration', get_duration);
			ExternalInterface.addCallback('get_ended', get_ended);
			ExternalInterface.addCallback('get_readyState', get_readyState);

			ExternalInterface.addCallback('set_src', set_src);
			ExternalInterface.addCallback('set_paused', set_paused);
			ExternalInterface.addCallback('set_volume', set_volume);
			ExternalInterface.addCallback('set_currentTime', set_currentTime);
			ExternalInterface.addCallback('set_duration', set_duration);

			ExternalInterface.addCallback('fire_load', fire_load);
			ExternalInterface.addCallback('fire_play', fire_play);
			ExternalInterface.addCallback('fire_pause', fire_pause);

			ExternalInterface.call('(function(){window["__ready__' + _id + '"]()})()', null);
		}

		private function isIllegalQuerystring():Boolean {
			var query:String = '';
			var pos:Number = root.loaderInfo.url.indexOf('?') ;

			if ( pos > -1 ) {
			    query = root.loaderInfo.url.substring( pos );
			    if ( ! /^\?\d+$/.test( query ) ) {
			        return true;
			    }
			}

			return false;
		}


		//
		// Javascript bridged methods
		//
		private function fire_load():void {
			if (!_isLoaded && _src) {

				_urlRequest = new URLRequest(_src);
				_urlStream.load(_urlRequest);

				sendEvent("loadedmetadata");

				if (_autoplay) {
					fire_play();
				}
			}
		}
		private function fire_play():void {

			_playWhenLoaded = true;

			if (!_isPlaying && _src) {

				if (_urlRequest == null) {
					fire_load();
					return;
				}

				_timer.stop();

				_channel = _decoder.play();
				_channel.removeEventListener(Event.SOUND_COMPLETE, soundCompleteHandler);
				_channel.addEventListener(Event.SOUND_COMPLETE, soundCompleteHandler);


				_isPlaying = true;
				_playWhenLoaded = false;
				_isEnded = false;

				sendEvent("play");
				sendEvent("playing");

				_timer.start();
			}
		}
		private function fire_pause():void {
			_playWhenLoaded = false;

			if (_isPlaying) {
				_channel.stop();
				_isPlaying = false;

				_timer.stop();

				sendEvent("pause");
			}
		}

		//
		// Setters
		//
		private function set_src(value:String = ''):void {
			_src = value;

			if (_playWhenLoaded) {
				fire_play();
			}
		}
		private function set_paused(value:*):void {
			// do nothing
		}
		private function set_volume(value:Number = NaN):void {
			if (!isNaN(value)) {

				_volume = value;

				if (_request) {
					_transform.volume = _volume;
					_channel.soundTransform = _transform;
				}
			}
		}
		private function set_duration(value:*):void {
			// do nothing
		}
		private function set_currentTime(value:Number = NaN):void {

			if (!isNaN(value) && _isPlaying) {

				sendEvent("seeking");

				_channel.stop();
				_currentTime = value;
				_channel = _sound.play(_currentTime * 1000, 0, _transform);

				sendEvent("seeked");

			}
		}

		//
		// Getters
		//
		private function get_src():String {
			return _src;
		}
		private function get_volume():Number {
			return _volume;
		}
		private function get_currentTime():Number {
			if (_channel != null) {
				_currentTime = _channel.position / 1000;
			}
			return _currentTime;
		}
		private function get_paused():Boolean {
			return !_isPlaying;
		}
		private function get_duration():Number {
			_duration = Math.abs(_decoder.getTotalTime() / 10);

			return _duration;
		}
		private function get_ended():Boolean {
			return _isEnded;
		}
		private function get_readyState():Number {
			return _readyState;
		}

		//
		// Event handlers
		//
		private function ioErrorHandler(event:Event):void {
			sendEvent("error", event.message);
		}
		private function timerHander(event:TimerEvent):void {

			if (_channel != null) {
				_currentTime = _channel.position / 1000;
			}

			sendEvent("timeupdate");
		}
		private function _idHandler(value:String = ""):Boolean {
			return (value === _id);
		}
		private function onDecoderInit(event:Event):void {
			sendEvent('loadedmetadata');
		}
		private function onIOError(event:IOErrorEvent):void {
			sendEvent('error', event.text);
		}

		private function onSoundComplete(event:Event):void {
			sendEvent('ended');
		}
		private function soundCompleteHandler(e:Event):void {
			handleEnded();
		}
		private function handleEnded():void {
			_timer.stop();
			_currentTime = 0;
			_isEnded = true;

			sendEvent("ended");
		}

		//
		// Utilities
		//
		private function sendEvent(eventName:String, eventMessage:String = ''):void {
			ExternalInterface.call('(function(){window["__event__' +  _id + '"]("' + eventName + '", "' + eventMessage + '")})()', null);
		}
		private function log():void {
			if (ExternalInterface.available) {
				ExternalInterface.call('console.log', arguments);
			} else {
				trace(arguments);
			}

		}
	}
}
