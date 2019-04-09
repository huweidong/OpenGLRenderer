//
//  RGBACopier.m
//  OpenGLRenderer
//
//  Created by apple on 2017/2/9.
//  Copyright © 2017年 xiaokai.zhan. All rights reserved.
//

#import "RGBAFrameCopier.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 varying vec2 v_texcoord;
 
 void main()
 {
     gl_Position = position;
     v_texcoord = texcoord.xy;
 }
);

NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, v_texcoord);
 }
);

@implementation RGBAFrameCopier
{
    NSInteger                           frameWidth;
    NSInteger                           frameHeight;
    
    GLuint                              filterProgram;
    GLint                               filterPositionAttribute;
    GLint                               filterTextureCoordinateAttribute;
    GLint                               filterInputTextureUniform;
    
    GLuint                              _inputTexture;
}
- (BOOL) prepareRender:(NSInteger)textureWidth height:(NSInteger)textureHeight;
{
    BOOL ret = NO;
    frameWidth = textureWidth;
    frameHeight = textureHeight;
    if([self buildProgram:vertexShaderString fragmentShader:rgbFragmentShaderString]) {
        //创建一个纹理对象
        glGenTextures(1, &_inputTexture);
        //绑定一个纹理对象
        glBindTexture(GL_TEXTURE_2D, _inputTexture);
        //控制放大或缩小
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        //限制纹理坐标范围是0～1
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        //将该RGBA到数组表示的像素内容上传到显卡里面到texId所代表的纹理对象中去
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)frameWidth, (GLsizei)frameHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        glBindTexture(GL_TEXTURE_2D, 0);
        ret = YES;
    }
    return ret;
}

- (BOOL) buildProgram:(NSString*) vertexShader fragmentShader:(NSString*) fragmentShader;
{
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    //创建一个对象作为程序的容器
    filterProgram = glCreateProgram();
    //编译Shader
    vertShader = compileShader(GL_VERTEX_SHADER, vertexShader);
    if (!vertShader)
        goto exit;
    fragShader = compileShader(GL_FRAGMENT_SHADER, fragmentShader);
    if (!fragShader)
        goto exit;
    //把编译的Shader附加到刚刚创建到程序中
    glAttachShader(filterProgram, vertShader);
    glAttachShader(filterProgram, fragShader);
    //链接程序
    glLinkProgram(filterProgram);
    
    filterPositionAttribute = glGetAttribLocation(filterProgram, "position");
    filterTextureCoordinateAttribute = glGetAttribLocation(filterProgram, "texcoord");
    filterInputTextureUniform = glGetUniformLocation(filterProgram, "inputImageTexture");
    
    GLint status;
    //检查程序到状态
    glGetProgramiv(filterProgram, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to link program %d", filterProgram);
        goto exit;
    }
    result = validateProgram(filterProgram);
exit:
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result) {
        NSLog(@"OK setup GL programm");
    } else {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
    return result;
}

- (void) renderFrame:(uint8_t*) rgbaFrame;
{
    glUseProgram(filterProgram);
    glClearColor(0.0f, 0.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    //将RGBA的数组表示的像素内容上传到显卡里面texId所代表纹理对象中去
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)frameWidth, (GLsizei)frameHeight,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, rgbaFrame);
    
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(filterPositionAttribute);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);
    //制定将要绘制的纹理对象，并且传递给对应的FragmentShader
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    glUniform1i(filterInputTextureUniform, 0);
    //执行绘制操作
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void) releaseRender;
{
    if (filterProgram) {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
    if(_inputTexture) {
        glDeleteTextures(1, &_inputTexture);
    }
}
@end
