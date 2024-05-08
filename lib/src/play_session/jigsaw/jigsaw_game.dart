import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/image_composition.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_jigsaw_puzzle/src/level_selection/jigsaw_info.dart';

import '../collision/puzzle_collision_detection.dart';
import '../shape_type.dart';
import 'image_utils.dart';
import 'piece_component.dart';

class JigsawGame extends FlameGame with HasCollisionDetection {
  int gridSize = 6;
  List<List<PieceComponent>> pieces = [[]];
  List<Vector2> positions = [];
  double pieceSize = 0;
  JigsawInfo jigsawInfo;
  double _scale = 1.0;
  bool isMusicOn;
  Function win;

  JigsawGame(this.jigsawInfo, this.isMusicOn, this.win);

  @override
  Future<void> onLoad() async {
    // 设置拼图游戏的碰撞检测系统
    collisionDetection = PuzzleCollisionDetection();

    // 此行被注释掉了，但如果取消注释，将在屏幕上显示帧率
    add(FpsTextComponent(position: Vector2(0, 50)));

    // 从缓存中获取拼图图片文件
    var file = await DefaultCacheManager().getSingleFile(jigsawInfo.image);

    // 将文件转换成Image对象
    Image image = await getFileImage(file);

    // 计算图片的缩放比例，以适应屏幕大小
    _scale = ImageUtils.calculateScale(size.x / 3.0 * 2.0, size.y / 3.0 * 2.0, image.width.toDouble(), image.height.toDouble());
    print("scale:$_scale");

    // 设置拼图的网格大小
    gridSize = jigsawInfo.gridSize;

    // 计算每块拼图的宽度和高度
    final double widthPerBlock = image.width / gridSize;
    final double heightPerBlock = image.height / gridSize;

    // 计算每块拼图的尺寸
    pieceSize = min(widthPerBlock, heightPerBlock) / 4;

    // 初始化拼图块列表并生成拼图块
    for (var y = 0; y < gridSize; y++) {
      final tmpPieces = <PieceComponent>[];
      pieces.add(tmpPieces);
      for (var x = 0; x < gridSize; x++) {
        // 创建每个拼图块并将其添加到对应的列表中
        PieceComponent player = getPiece(widthPerBlock, heightPerBlock, x, y, image);
        pieces[y].add(player);
      }
    }

    // 随机化拼图块的初始位置
    positions.shuffle();

    // 设置拼图块的位置并将它们添加到游戏中
    for (var y = 0; y < pieces.length; y++) {
      for (var x = 0; x < pieces[y].length; x++) {
        // 根据随机化后的位置列表获取当前拼图块的位置
        Vector2 position = positions[y * gridSize + x];
        var piece = pieces[y][x];

        // 如果拼图块的上侧或左侧没有凸起，则调整它们的位置
        if (piece.shape.topTab == 0) {
          position.y = position.y + pieceSize * _scale;
        }
        if (piece.shape.leftTab == 0) {
          position.x = position.x + pieceSize * _scale;
        }

        // 进一步调整拼图块的水平位置
        position.x = position.x + positionOffsetX;

        // 设置拼图块的位置
        piece.position = position;

        // 将拼图块添加到游戏世界中，使其可见
        add(piece);
      }
    }
  }

  getResult(int num, bool added) async {
    if (num == gridSize * gridSize) {
      print("getResult win:$num");
      win();
      if (isMusicOn) {
        FlameAudio.play('won.wav');
      }
    } else {
      print("getResult isMusicOn:$isMusicOn");
      if (added && isMusicOn) {
        FlameAudio.play('click.wav');
      }
    }
  }

  Future<Image> getFileImage(File filePath) async {
    var minHeight = (size.y / 3.0 * 2.0).toInt();
    var minWidth = (size.x / 3.0 * 2.0).toInt();
    print("minHeight:$minHeight minWidth:$minWidth");
    // var list = await FlutterImageCompress.compressWithFile(
    //   filePath,
    //   minHeight: minHeight,
    //   minWidth: minWidth,
    //   quality: 99,
    //   rotate: 0,
    // );

    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(filePath.readAsBytesSync(), (ui.Image img) {
      print("image width:${img.width} image height:${img.height}:");
      return completer.complete(img);
    });
    return completer.future;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    print("onGameResize:$size");
  }

  PieceComponent getPiece(double widthPerBlock, double heightPerBlock, int x, int y, Image image) {
    // 根据当前的网格位置(x, y)获取拼图块的形状
    Shape shape = _getShape(gridSize, x, y);

    // 计算拼图块在图片上的起始x和y坐标
    double xAxis = widthPerBlock * x;
    double yAxis = heightPerBlock * y;

    // 如果拼图块的左侧或顶部有凸起或凹进，则调整x和y坐标，以确保准确裁剪
    xAxis -= shape.leftTab != 0 ? pieceSize : 0;
    yAxis -= shape.topTab != 0 ? pieceSize : 0;

    // 计算拼图块的实际宽度和高度，考虑到左侧/右侧和顶部/底部的凸起或凹进
    final double widthPerBlockTemp = widthPerBlock + (shape.leftTab != 0 ? pieceSize : 0) + (shape.rightTab != 0 ? pieceSize : 0);
    final double heightPerBlockTemp = heightPerBlock + (shape.topTab != 0 ? pieceSize : 0) + (shape.bottomTab != 0 ? pieceSize : 0);

    // 创建拼图块的SpriteComponent，指定其在原始图片中的位置和大小
    final piece = PieceComponent(
      SpriteComponent(
          sprite: Sprite(
            image, // 原始图片
            srcPosition: Vector2(xAxis, yAxis), // 拼图块在原始图片中的起始位置
            srcSize: Vector2(widthPerBlockTemp, heightPerBlockTemp), // 拼图块的大小
          ),
          size: Vector2(widthPerBlockTemp * _scale, heightPerBlockTemp * _scale)), // 考虑到缩放后的拼图块大小
      shape, // 拼图块的形状
      pieceSize * _scale, // 缩放后的拼图块尺寸
      x, // 拼图块在网格中的x坐标
      y, // 拼图块在网格中的y坐标
    );

    // 生成拼图块的底部位置（这可能用于后续的布局或碰撞检测）
    generatePositionBottom(widthPerBlock * _scale, heightPerBlock * _scale);

    // 返回创建的拼图块
    return piece;
  }

  ///
  /// 随机 1 凸起 2凹进去，0 平的
  Shape _getShape(int gridSize, int x, int y) {
    // 随机决定拼图块在行方向的凸起或凹进（1表示凸起，-1表示凹进）
    final int randomPosRow = math.Random().nextInt(2).isEven ? 1 : -1;
    // 随机决定拼图块在列方向的凸起或凹进（1表示凸起，-1表示凹进）
    final int randomPosCol = math.Random().nextInt(2).isEven ? 1 : -1;

    // 创建一个新的Shape对象
    Shape shape = Shape();

    // 如果当前拼图块是在最底部的行，它的底部不应有凸起或凹进，否则随机设置
    shape.bottomTab = y == gridSize - 1 ? 0 : randomPosCol;

    // 如果当前拼图块是在最左边的列，它的左侧不应有凸起或凹进
    // 否则，它的左侧凸起或凹进应与左边拼图块的右侧相反
    shape.leftTab = x == 0 ? 0 : -pieces[y][x - 1].shape.rightTab;

    // 如果当前拼图块是在最右边的列，它的右侧不应有凸起或凹进，否则随机设置
    shape.rightTab = x == gridSize - 1 ? 0 : randomPosRow;

    // 如果当前拼图块是在最顶部的行，它的顶部不应有凸起或凹进
    // 否则，它的顶部凸起或凹进应与上方拼图块的底部相反
    shape.topTab = y == 0 ? 0 : -pieces[y - 1][x].shape.bottomTab;

    // 返回设置好的拼图块形状
    return shape;
  }


  double pieceX = 0;
  double pieceY = 0;
  bool left = true;
  double positionOffsetX = -1;

  void generatePositionLeftRight(double widthPerBlock, double heightPerBlock) {
    int width = (widthPerBlock.toInt() + pieceSize * _scale * 2).toInt();
    int height = (heightPerBlock.toInt() + pieceSize * _scale * 2).toInt();
    pieceY = pieceY + height;
    if (positions.length == 0) {
      pieceY = 0;
    }
    if (pieceY + height > size.y) {
      if (left) {
        pieceX = size.x - pieceX - width;
        left = false;
      } else {
        pieceX = size.x - pieceX;
        left = true;
      }
      pieceY = 0;
    }
    // print(" pieceX:$pieceX pieceY:$pieceY");
    positions.add(Vector2(pieceX, pieceY));
  }

  void generatePositionBottom(double widthPerBlock, double heightPerBlock) {
    int width = (widthPerBlock.toInt() + pieceSize * _scale * 2).toInt();
    int height = (heightPerBlock.toInt() + pieceSize * _scale * 2).toInt();
    pieceX = pieceX - width;
    if (positions.length == 0) {
      pieceX = size.x - width;
      pieceY = size.y - height;
    }

    if (pieceX < 0) {
      if (positionOffsetX == -1) {
        positionOffsetX = -((pieceX + width) / 2.0);
      }
      pieceX = size.x - width;
      pieceY = pieceY - height;
    }
    // print(" pieceX:$pieceX pieceY:$pieceY");
    positions.add(Vector2(pieceX, pieceY));
  }
}
