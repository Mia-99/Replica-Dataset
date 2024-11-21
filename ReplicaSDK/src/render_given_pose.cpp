// Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#include <EGL.h>
#include <PTexLib.h>
#include <iostream>
#include <map>
#include <pangolin/image/image_convert.h>
#include <pangolin/var/var.h>
#include <string>

#include "GLCheck.h"
#include "MirrorRenderer.h"

// define the inv_Pose function
Eigen::Matrix4d inv_Pose(const Eigen::Matrix4d &T) {
  Eigen::Matrix4d T_inv = Eigen::Matrix4d::Identity();
  T_inv.topLeftCorner(3, 3) = T.topLeftCorner(3, 3).transpose();
  T_inv.topRightCorner(3, 1) =
      -T.topLeftCorner(3, 3).transpose() * T.topRightCorner(3, 1);
  return T_inv;
}

std::vector<std::tuple<int, int, double>> parseAndTranslateChanges(const std::string& changes, size_t numPoses) {
    std::vector<std::tuple<int, int, double>> parsedRanges;

    if (changes.empty()) {
        return parsedRanges; // No changes
    }
    std::cout << "Input string: " << changes << std::endl;

    std::vector<std::pair<int, double>> tempPairs;
    size_t pos = 0;
    std::string remaining = changes;

    // Split input string based on closing parenthesis `)`
    while ((pos = remaining.find(')')) != std::string::npos) {
        std::string pairStr = remaining.substr(0, pos + 1); // Extract up to `)`
        remaining = remaining.substr(pos + 1); // Remove processed part

        if (pairStr.front() == '(' && pairStr.back() == ')') {
            pairStr = pairStr.substr(1, pairStr.size() - 2); // Remove parentheses

            std::istringstream pairStream(pairStr);
            std::string startStr, focalStr;
            if (std::getline(pairStream, startStr, ',') && std::getline(pairStream, focalStr)) {
                int start = std::stoi(startStr);
                double focal = std::stod(focalStr);
                tempPairs.emplace_back(start, focal);
            } else {
                std::cout << "Failed to parse: " << pairStr << std::endl;
            }
        }
    }

    // Translate pairs into ranges
    for (size_t i = 0; i < tempPairs.size(); ++i) {
        int start = tempPairs[i].first;
        double focal = tempPairs[i].second;
        // Ensure the range ends right before the next start, or at the end of numPoses
        int end = (i + 1 < tempPairs.size()) ? tempPairs[i + 1].first - 1 : static_cast<int>(numPoses) - 1;
        parsedRanges.emplace_back(start, end, focal);
        std::cout << "Range: " << start << "-" << end << ", Focal: " << focal << std::endl;
    }

    return parsedRanges;
}

int main(int argc, char *argv[]) {
  // ASSERT(argc == 3 || argc == 4, "Usage: ./ReplicaRenderer mesh.ply "
  //                                "/path/to/atlases traj.txt [mirrorFile]");
  ASSERT(argc == 8 || argc == 9, "Usage: ./ReplicaRenderer width height focal focal_changes traj.txt mesh.ply "
                                 "/path/to/atlases [mirrorFile]");
  // read traj.txt
  const int width = std::stoi(argv[1]);
  const int height = std::stoi(argv[2]);
  double focal = std::stof(argv[3]);
  std::string changes = argv[4];
  // stript it by space
  // changes = "(id, focal)(id, focal)..."
  // changes = "(100, 300, 200.0) (300, 700, 600.0) (700, 2000, 200.0)"
  // changes = ""
  

  const std::string trajFile(argv[5]);
  const std::string meshFile(argv[6]);
  const std::string atlasFolder(argv[7]);
  // const std::string trajFile(argv[3]);
  ASSERT(pangolin::FileExists(meshFile));
  ASSERT(pangolin::FileExists(atlasFolder));
  // ASSERT(pangolin::FileExists(trajFile));

  // load all the poses
  // std::string trajFile = "/datasets/replica_origin/office4/traj.txt";
  std::vector<Eigen::Matrix4d> poses;
  std::vector<Eigen::Matrix4d> poses_original;
  std::ifstream file(trajFile);
  if (!file.is_open()) {
    std::cerr << "Failed to open file: " << trajFile << std::endl;
    return 1;
  }
  std::string line;
  while (std::getline(file, line)) {
    std::istringstream iss(line);
    Eigen::Matrix4d T_w_c;
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        iss >> T_w_c(i, j);
      }
    }
    poses_original.push_back(T_w_c);
  }
  for (size_t i = 0; i < poses_original.size(); i+=1) {
    poses.push_back(poses_original[i]);
  }

  // std::vector<double> focals;
  std::vector<double> focals(poses.size(), focal);
  std::vector<std::tuple<int, int, double>> parsedChanges = parseAndTranslateChanges(changes, poses.size());
  // 
  if (!parsedChanges.empty()) {
      for (const auto& change : parsedChanges) {
          int startID = std::get<0>(change);
          int endID = std::get<1>(change);
          double newFocal = std::get<2>(change);
          // Ensure the range is within bounds
          if (startID >= 0 && endID < static_cast<int>(poses.size()) && startID <= endID) {
              for (int id = startID; id <= endID; ++id) {
                  focals[id] = newFocal;
              }
          }
      }
  }

  // for (size_t i = 0; i < poses.size(); i++) {
  //   focals.push_back(focal);
  // }
  // write a intrinsics file
  std::ofstream intrinsicsFile("intrinsics.txt");
  for (size_t i = 0; i < poses.size(); i++) {
    intrinsicsFile << focals[i] << std::endl;
  }

  std::string surfaceFile;
  if (argc == 8) {
    surfaceFile = std::string(argv[8]);
    ASSERT(pangolin::FileExists(surfaceFile));
  }

  // const int width = 800;
  // const int height = 600;
  // const int width = 400;
  // const int height = 300;
  // const int width = 1200;
  // const int height = 680;
  bool renderDepth = true;
  float depthScale = 65535.0f * 0.1f;

  // Setup EGL
  EGLCtx egl;

  egl.PrintInformation();

  if (!checkGLVersion()) {
    return 1;
  }

  // Don't draw backfaces
  const GLenum frontFace = GL_CCW;
  glFrontFace(frontFace);

  // Setup a framebuffer
  pangolin::GlTexture render(width, height);
  pangolin::GlRenderBuffer renderBuffer(width, height);
  pangolin::GlFramebuffer frameBuffer(render, renderBuffer);

  pangolin::GlTexture depthTexture(width, height, GL_R32F, false, 0, GL_RED,
                                   GL_FLOAT, 0);
  pangolin::GlFramebuffer depthFrameBuffer(depthTexture, renderBuffer);
  // fx = fy = 300 - 800
  // Setup a camera
  // Calibration
  //     : fx : 600.0 fy : 600.0
  //       cx : 599.5 cy : 339.5 k1 : 0.0 k2 : 0.0 p1 : 0.0 p2 : 0.0 k3 : 0.0
  // pangolin::OpenGlRenderState s_cam(
  //     pangolin::ProjectionMatrixRDF_BottomLeft(
  //         width, height, width / 2.0f, width / 2.0f, (width - 1.0f) / 2.0f,
  //         (height - 1.0f) / 2.0f, 0.1f, 100.0f),
  //     pangolin::ModelViewLookAtRDF(0, 0, 4, 0, 0, 0, 0, 1, 0));

  // // Start at some origin
  // Eigen::Matrix4d T_camera_world = s_cam.GetModelViewMatrix();

  // // And move to the left
  // Eigen::Matrix4d T_new_old = Eigen::Matrix4d::Identity();

  // T_new_old.topRightCorner(3, 1) = Eigen::Vector3d(0.025, 0, 0);

  // load mirrors
  std::vector<MirrorSurface> mirrors;
  if (surfaceFile.length()) {
    std::ifstream file(surfaceFile);
    picojson::value json;
    picojson::parse(json, file);

    for (size_t i = 0; i < json.size(); i++) {
      mirrors.emplace_back(json[i]);
    }
    std::cout << "Loaded " << mirrors.size() << " mirrors" << std::endl;
  }

  const std::string shadir = STR(SHADER_DIR);
  MirrorRenderer mirrorRenderer(mirrors, width, height, shadir);

  // load mesh and textures
  PTexMesh ptexMesh(meshFile, atlasFolder);
  pangolin::Var<float> exposure("ui.Exposure", 0.01, 0.0f, 0.1f);

  pangolin::ManagedImage<Eigen::Matrix<uint8_t, 3, 1>> image(width, height);
  pangolin::ManagedImage<float> depthImage(width, height);
  pangolin::ManagedImage<uint16_t> depthImageInt(width, height);

  ptexMesh.SetExposure(exposure);

  // Render some frames
  const size_t numFrames = poses.size();
  // const size_t numFrames = 2;
  for (size_t i = 0; i < numFrames; i++) {

    std::cout << "\rRendering frame " << i + 1 << "/" << numFrames << "... ";
    std::cout.flush();

    // set the camera pose & focal
    pangolin::OpenGlMatrix mv;
    // poses[i] is T_w_c
    memcpy(&mv.m[0], inv_Pose(poses[i]).data(), sizeof(double) * 16);
    pangolin::OpenGlRenderState s_cam(pangolin::ProjectionMatrixRDF_BottomLeft(
                                          width, height, focals[i], focals[i],
                                          (width - 1.0f) / 2.0f,
                                          (height - 1.0f) / 2.0f, 0.1f, 100.0f),
                                      mv);
    // Render
    frameBuffer.Bind();
    glPushAttrib(GL_VIEWPORT_BIT);
    glViewport(0, 0, width, height);
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);

    glEnable(GL_CULL_FACE);

    ptexMesh.Render(s_cam);

    glDisable(GL_CULL_FACE);

    glPopAttrib(); // GL_VIEWPORT_BIT
    frameBuffer.Unbind();

    for (size_t i = 0; i < mirrors.size(); i++) {
      MirrorSurface &mirror = mirrors[i];
      // capture reflections
      mirrorRenderer.CaptureReflection(mirror, ptexMesh, s_cam, frontFace);

      frameBuffer.Bind();
      glPushAttrib(GL_VIEWPORT_BIT);
      glViewport(0, 0, width, height);

      // render mirror
      mirrorRenderer.Render(mirror, mirrorRenderer.GetMaskTexture(i), s_cam);

      glPopAttrib(); // GL_VIEWPORT_BIT
      frameBuffer.Unbind();
    }

    // Download and save
    render.Download(image.ptr, GL_RGB, GL_UNSIGNED_BYTE);

    char filename[1000];
    snprintf(filename, 1000, "frame%06zu.jpg", i);

    pangolin::SaveImage(image.UnsafeReinterpret<uint8_t>(),
                        pangolin::PixelFormatFromString("RGB24"),
                        std::string(filename));

    if (renderDepth) {
      // render depth
      depthFrameBuffer.Bind();
      glPushAttrib(GL_VIEWPORT_BIT);
      glViewport(0, 0, width, height);
      glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);

      glEnable(GL_CULL_FACE);

      ptexMesh.RenderDepth(s_cam, depthScale);

      glDisable(GL_CULL_FACE);

      glPopAttrib(); // GL_VIEWPORT_BIT
      depthFrameBuffer.Unbind();

      depthTexture.Download(depthImage.ptr, GL_RED, GL_FLOAT);

      // convert to 16-bit int
      for (size_t i = 0; i < depthImage.Area(); i++)
        depthImageInt[i] = static_cast<uint16_t>(depthImage[i] + 0.5f);

      snprintf(filename, 1000, "depth%06zu.png", i);
      pangolin::SaveImage(depthImageInt.UnsafeReinterpret<uint8_t>(),
                          pangolin::PixelFormatFromString("GRAY16LE"),
                          std::string(filename), true, 34.0f);
    }

    // // Move the camera
    // T_camera_world = T_camera_world * T_new_old.inverse();

    // s_cam.GetModelViewMatrix() = T_camera_world;
  }
  std::cout << "\rRendering frame " << numFrames << "/" << numFrames
            << "... done" << std::endl;

  return 0;
}
