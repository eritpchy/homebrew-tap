class VideoSubtitleRemover < Formula
  include Language::Python::Virtualenv
  desc "AI-based tool for removing hard-coded subtitles and text-like watermarks from videos or Pictures."
  homepage "https://github.com/YaoFANGUK/video-subtitle-remover"
  url "https://github.com/eritpchy/video-subtitle-remover/archive/refs/tags/1.4.0.tar.gz"
  sha256 "27ae99ddce6da01920b89e68505a6d1d8982f8054378cece14b79967fce0298d"
  version "1.4.0"
  license "Apache-2.0"

  depends_on "python@3.12"

  def install
    # 创建虚拟环境
    venv = virtualenv_create(libexec, "python3.12")
    
    # Install pip explicitly first
    venv.pip_install "pip"
    
    # 检测系统语言是否为中文
    is_cn_user = system("defaults read -g AppleLanguages | grep -q 'zh'") rescue false
    if is_cn_user
      # 中文用户使用清华源
      mirror = "https://pypi.tuna.tsinghua.edu.cn/simple"
      puts "Detect CN user, use mirror: #{mirror}"
      system libexec/"bin/pip", "config", "set", "--site", "global.extra-index-url", mirror
    end
    
    if Hardware::CPU.arm?
      # Apple Silicon (ARM) 的配置
      execute([libexec/"bin/pip", "install", "paddlepaddle==3.0.0", "-i", "https://www.paddlepaddle.org.cn/packages/stable/cpu/"])
      execute([libexec/"bin/pip", "install", "torch==2.7.0", "torchvision==0.22.0"])
      execute([libexec/"bin/pip", "install", "-r", buildpath/"requirements.txt"])
    else
      # x86_64 的配置
      execute([libexec/"bin/pip", "install", "paddlepaddle==3.0.0", "numpy==1.26.4", "-i", "https://www.paddlepaddle.org.cn/packages/stable/cpu/"])
      execute([libexec/"bin/pip", "install", "torch", "torchvision", "numpy==1.26.3", "-i", "https://download.pytorch.org/whl/cpu"])
      execute([libexec/"bin/pip", "install", "-r", buildpath/"requirements.txt"])
    end

    # 复制项目文件到目标目录  
    prefix.install Dir["*"]
    
    # 创建可执行脚本
    (bin/"video-subtitle-remover").write <<~EOS
      #!/bin/bash
      export PYTHONPATH="#{prefix}"
      exec "#{libexec}/bin/python" "#{prefix}/gui.py" "$@"
    EOS

    # 创建可执行脚本
    (bin/"video-subtitle-remover-cli").write <<~EOS
      #!/bin/bash
      export PYTHONPATH="#{prefix}"
      exec "#{libexec}/bin/python" "#{prefix}/backend/main.py" "$@"
    EOS
    
    # 创建 .app 应用包
    app_path = prefix/"VideoSubtitleRemover.app"/"Contents"
    mkdir_p "#{app_path}/MacOS"
    mkdir_p "#{app_path}/Resources"
    system "cp", "-rfv", prefix/"design/AppIcon.icns", "#{app_path}/Resources" if File.exist?("/path/to/file")
    
    # 创建 Info.plist
    (app_path/"Info.plist").write <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>English</string>
        <key>CFBundleExecutable</key>
        <string>VideoSubtitleRemover</string>
        <key>CFBundleIconFile</key>
        <string>AppIcon.icns</string>
        <key>CFBundleIdentifier</key>
        <string>com.yaofanguk.videosubtitleremover</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>VideoSubtitleRemover</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>1.4.0</string>
        <key>CFBundleVersion</key>
        <string>1</string>
        <key>NSHighResolutionCapable</key>
        <true/>
      </dict>
      </plist>
    EOS
    
    # 创建启动脚本
    (app_path/"MacOS"/"VideoSubtitleRemover").write <<~EOS
      #!/bin/bash
      export PYTHONPATH="#{prefix}"
      exec "#{libexec}/bin/python" "#{prefix}/gui.py" "$@"
    EOS
    
    # 设置可执行权限
    chmod 0755, app_path/"MacOS"/"VideoSubtitleRemover"
    chmod 0755, bin/"video-subtitle-remover"
    
    # test
    system libexec/"bin/python", "-c", "import torch;import torchvision;import paddle;import paddleocr"
    ENV["PYTHONPATH"] = prefix.to_s
    system libexec/"bin/python", prefix/"backend/main.py", "--help"
    
    # Workaround RuntimeError: operator torchvision::nms does not exist
    system "bash", "-c", <<~EOS
      cd "#{prefix}" &&
      find . -type f \\( -name "*.so" -o -name "*.dylib" \\) -print0 \\
        | tar -cvf "#{prefix/"backup.tar"}" --null -T - -C "#{prefix}" &&
      find . -type f \\( -name "*.so" -o -name "*.dylib" \\) -delete
    EOS
  end

  def caveats
    is_cn_user = system("defaults read -g AppleLanguages | grep -q 'zh'") rescue false
    if is_cn_user
        <<~EOS
            字幕去除器已安装！
            
            你可以通过以下方式运行：
            
            1. 命令行：
                video-subtitle-remover
                video-subtitle-remover-cli
                
            2. 应用程序：
                在 Applications 文件夹中找到 VideoSubtitleRemover
        EOS
    else
        <<~EOS
            Subtitle Remover has been installed!
            
            You can run it in the following ways:
            
            1. Command line:
                video-subtitle-remover
                video-subtitle-remover-cli
                
            2. Application:
                Find VideoSubtitleRemover in your Applications folder
        EOS
    end
  end

  def post_install
    # Workaround RuntimeError: operator torchvision::nms does not exist
    system "tar", "-xvf", prefix/"backup.tar", "-C", prefix
    File.delete(prefix/"backup.tar")
  end
  
  require "open3"
  def execute(command)
    Open3.popen2e(*command) do |stdin, stdout_err, wait_thr|
      stdin.close_write
      stdout_err.each_char { |c| print c }
      exit_status = wait_thr.value
      unless exit_status.success?
        raise "Install Failed, exit code: #{exit_status.exitstatus}"
      end
    end
  end
end