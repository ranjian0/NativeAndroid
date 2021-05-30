#include "glfm.h"
#include <string.h>

static GLint program = 0;
static GLuint vertexBuffer = 0;

static void onFrame(GLFMDisplay *display);
static void onSurfaceCreated(GLFMDisplay *display, int width, int height);
static void onSurfaceDestroyed(GLFMDisplay *display);

void glfmMain(GLFMDisplay *display) {
    glfmSetDisplayConfig(display,
                         GLFMRenderingAPIOpenGLES2,
                         GLFMColorFormatRGBA8888,
                         GLFMDepthFormatNone,
                         GLFMStencilFormatNone,
                         GLFMMultisampleNone);
    glfmSetSurfaceCreatedFunc(display, onSurfaceCreated);
    glfmSetSurfaceResizedFunc(display, onSurfaceCreated);
    glfmSetSurfaceDestroyedFunc(display, onSurfaceDestroyed);
    glfmSetRenderFunc(display, onFrame);
}

static void onSurfaceCreated(GLFMDisplay *display, int width, int height) {
    glViewport(0, 0, width, height);
}

static void onSurfaceDestroyed(GLFMDisplay *display) {
    // When the surface is destroyed, all existing GL resources are no longer valid.
    program = 0;
    vertexBuffer = 0;
}

static GLuint compileShader(const GLenum type, const GLchar *shaderString) {
    const GLint shaderLength = (GLint)strlen(shaderString);
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &shaderString, &shaderLength);
    glCompileShader(shader);
    return shader;
}

static void onFrame(GLFMDisplay *display) {
    if (program == 0) {
        const GLchar *vertexShader =
            "attribute highp vec4 position;\n"
            "void main() {\n"
            "   gl_Position = position;\n"
            "}";

        const GLchar *fragmentShader =
            "void main() {\n"
            "  gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);\n"
            "}";

        program = glCreateProgram();
        GLuint vertShader = compileShader(GL_VERTEX_SHADER, vertexShader);
        GLuint fragShader = compileShader(GL_FRAGMENT_SHADER, fragmentShader);

        glAttachShader(program, vertShader);
        glAttachShader(program, fragShader);

        glLinkProgram(program);

        glDeleteShader(vertShader);
        glDeleteShader(fragShader);
    }
    if (vertexBuffer == 0) {
        const GLfloat vertices[] = {
             0.0,  0.5, 0.0,
            -0.5, -0.5, 0.0,
             0.5, -0.5, 0.0,
        };
        glGenBuffers(1, &vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    }

    glClearColor(0.4f, 0.0f, 0.6f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(program);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    
    glfmSwapBuffers(display);
}