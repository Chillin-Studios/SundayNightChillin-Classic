package states;


#if VIDEOS_ALLOWED
import objects.VideoSprite;
#end

import psychlua.LuaUtils;
import backend.Highscore;

import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.keyboard.FlxKey;

import haxe.Json;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

import shaders.ColorSwap;

import states.StoryMenuState;
import states.OutdatedState;
import states.MainMenuState;

typedef TitleData =
{
	bumpinData:BumpinData,
	checkerData:CheckerData,
	startData:StartData,
	backgroundSprite:String,
	bpm:Float
}

typedef BumpinData =
{
	positions:Array<Float>,
	prefix:String,
	screenCenter:String,
	rotating:Bool,
	rotatingProperties:{
		angle:Float,
		time:Float,
		ease:String
	}
}

typedef StartData =
{
	positions:Array<Float>,
	prefixes:{
		idle:String,
		press:String,
		freeze:String
	},
	screenCenter:String,
	colors:Array<String>,
	alphas:Array<Float>
}

class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;
	public static var titleJSON:TitleData;
	public static var updateVersion:String = '';

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var credTextShit:Alphabet;
	var textGroup:FlxGroup;
	var logoSpr:FlxSprite;

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	var mustUpdate:Bool = false;

	override public function create():Void
	{
		Paths.clearStoredMemory();

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];

		curWacky = FlxG.random.getObject(getIntroTextShit());

		super.create();

		FlxG.save.bind('funkin', CoolUtil.getSavePath());

		ClientPrefs.loadPrefs();

		#if CHECK_FOR_UPDATES
		if(ClientPrefs.data.checkForUpdates && !closedState) {
			trace('checking for update');
			var http = new haxe.Http("https://raw.githubusercontent.com/Chillin-Studios/SundayNightChillin-Classic/main/gitVersion.txt");

			http.onData = function (data:String)
			{
				updateVersion = data.split('\n')[0].trim();
				var curVersion:String = MainMenuState.chillinVersion.trim();
				trace('version online: ' + updateVersion + ', your version: ' + curVersion);
				if(updateVersion != curVersion) {
					trace('versions arent matching!');
					mustUpdate = true;
				}
			}

			http.onError = function (error) {
				trace('error: $error');
			}

			http.request();
		}
		#end

		Highscore.load();

		titleJSON = tjson.TJSON.parse(Paths.getTextFromFile('data/titleScreen.json'));

		if(!initialized)
		{
			if(FlxG.save.data != null && FlxG.save.data.fullscreen)
			{
				FlxG.fullscreen = FlxG.save.data.fullscreen;
			}
			persistentUpdate = true;
			persistentDraw = true;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		FlxG.mouse.visible = false;
		#if FREEPLAY
		MusicBeatState.switchState(new FreeplaySelector());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if (FlxG.save.data.sawWelcomeState == null && !WelcomeState.leftState || FlxG.save.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;

			if (FlxG.save.data.sawWelcomeState == null && !WelcomeState.leftState)
				MusicBeatState.switchState(new WelcomeState());
			else if (FlxG.save.data.flashing == null && !FlashingState.leftState)
				MusicBeatState.switchState(new FlashingState());
		}
		else
		{
			if (initialized)
				startIntro();
			else
			{
				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					startIntro();
				});
			}
		}
		#end
	}

	var logoBl:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;

	function startIntro()
	{
		if (!initialized)
		{
			if(FlxG.sound.music == null) {
				FlxG.sound.playMusic(Paths.music('sncTitle'), 0);
			}
		}

		Conductor.bpm = titleJSON.bpm;
		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite();
		bg.antialiasing = ClientPrefs.data.antialiasing;

		if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.length > 0 && titleJSON.backgroundSprite != "none")
			bg.loadGraphic(Paths.image(titleJSON.backgroundSprite));
		else
			bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);

		add(bg);

		if (titleJSON.checkerData.enabled)
		{
			var checkeredBG:Checkers = new Checkers(titleJSON.checkerData);
			add(checkeredBG);
		}

		logoBl = new FlxSprite();
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.antialiasing = ClientPrefs.data.antialiasing;

		switch (titleJSON.bumpinData.screenCenter.toLowerCase())
		{
			case 'x':
				logoBl.screenCenter(X);
			case 'y':
				logoBl.screenCenter(Y);
			case '':
			default:
				logoBl.screenCenter(XY);
		}

		logoBl.x += titleJSON.bumpinData.positions[0];
		logoBl.y += titleJSON.bumpinData.positions[1];

		logoBl.animation.addByPrefix('bump', titleJSON.bumpinData.prefix, 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		if(ClientPrefs.data.shaders) swagShader = new ColorSwap();
		add(logoBl);
		if(swagShader != null)
			logoBl.shader = swagShader.shader;

		if (titleJSON.bumpinData.rotating)
		{
			logoBl.angle = titleJSON.bumpinData.rotatingProperties.angle;
			FlxTween.tween(logoBl, {angle: -titleJSON.bumpinData.rotatingProperties.angle}, titleJSON.bumpinData.rotatingProperties.time,
			{
				ease: LuaUtils.getTweenEaseByString(titleJSON.bumpinData.rotatingProperties.ease),
				type: PINGPONG
			});
		}

		titleText = new FlxSprite();
		titleText.frames = Paths.getSparrowAtlas('titleEnter');

		switch (titleJSON.startData.screenCenter.toLowerCase())
		{
			case 'x':
				titleText.screenCenter(X);
			case 'y':
				titleText.screenCenter(Y);
			case '':
			default:
				titleText.screenCenter(XY);
		}

		titleText.x += titleJSON.startData.positions[0];
		titleText.y += titleJSON.startData.positions[1];

		titleText.animation.addByPrefix('idle', titleJSON.startData.prefixes.idle, 24);
		titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? titleJSON.startData.prefixes.press : titleJSON.startData.prefixes.freeze, 24);
		titleText.animation.play('idle');
		titleText.updateHitbox();
		add(titleText);

		credGroup = new FlxGroup();
		add(credGroup);
		textGroup = new FlxGroup();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();

		credTextShit.visible = false;

		logoSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('titlelogo'));
		add(logoSpr);
		logoSpr.visible = false;
		logoSpr.setGraphicSize(Std.int(logoSpr.width * 0.8));
		logoSpr.updateHitbox();
		logoSpr.screenCenter(X);
		logoSpr.antialiasing = ClientPrefs.data.antialiasing;

		if (initialized)
			skipIntro();
		else
			initialized = true;

		Paths.clearUnusedMemory();
	}

	function getIntroTextShit():Array<Array<String>>
	{
		#if MODS_ALLOWED
		var firstArray:Array<String> = Mods.mergeAllTextsNamed('data/introText.txt', Paths.getSharedPath());
		#else
		var fullText:String = Assets.getText(Paths.txt('introText'));
		var firstArray:Array<String> = fullText.split('\n');
		#end
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		titleTimer += FlxMath.bound(elapsed, 0, 1);
		if (titleTimer > 2) titleTimer -= 2;

		if (initialized && !transitioning && skippedIntro)
		{
			var timer:Float = titleTimer;
			if (timer >= 1)
				timer = (-timer) + 2;

			timer = FlxEase.quadInOut(timer);
			titleText.color = FlxColor.interpolate(FlxColor.fromString('#${titleJSON.startData.colors[0]}'), FlxColor.fromString('#${titleJSON.startData.colors[1]}'), timer);
			titleText.alpha = FlxMath.lerp(titleJSON.startData.alphas[0], titleJSON.startData.alphas[1], timer);

			if(pressedEnter)
			{
				titleText.color = FlxColor.fromString('#${titleJSON.startData.colors[2]}');
				titleText.alpha = 1;

				if(titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : FlxColor.BLACK, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					#if VIDEOS_ALLOWED
					if (WelcomeState.isWhatYoutuber == SABER) {
						if (FlxG.sound.music != null)
							FlxG.sound.music.stop();

						var kids:VideoSprite = new VideoSprite(Paths.video('best_intro'), false, false, false);
						kids.finishCallback = function()
						{
							FlxTransitionableState.skipNextTransIn = true;
							FlxTransitionableState.skipNextTransOut = true;
							
							FlxG.sound.playMusic(Paths.music('sncTitle'));
							
							if (mustUpdate) {
								MusicBeatState.switchState(new OutdatedState());
							} else {
								MusicBeatState.switchState(new MainMenuState());
							}
						};
						add(kids);
						kids.videoSprite.play();
					} else
					#end
					if (mustUpdate) {
						MusicBeatState.switchState(new OutdatedState());
					} else {
						MusicBeatState.switchState(new MainMenuState());
					}
					closedState = true;
				});
			}
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if(credGroup != null && textGroup != null) {
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0;
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();

		if(logoBl != null)
			logoBl.animation.play('bump', true);

		if(!closedState) {
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
					FlxG.sound.playMusic(Paths.music('sncTitle'), 0);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 2:
					createCoolText(['Chillin\' Studios']);
				case 4:
					addMoreText('presents');
				case 5:
					deleteCoolText();
				case 6:
					createCoolText(['In association', 'with'], -40);
				case 8:
					addMoreText('Friday Night Funkin\'', -40);
					logoSpr.visible = true;
				case 9:
					deleteCoolText();
					logoSpr.visible = false;
				case 10:
					createCoolText([curWacky[0]]);
				case 12:
					addMoreText(curWacky[1]);
				case 13:
					deleteCoolText();
				case 14:
					addMoreText('Sunday');
				case 15:
					addMoreText('Night');
				case 16:
					addMoreText('Chillin\'');

				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			remove(logoSpr);
			remove(credGroup);
			FlxG.camera.flash(FlxColor.WHITE, 4);
			skippedIntro = true;
		}
	}
}
