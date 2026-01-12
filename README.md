# OpenSCAD App

A modern application for visualizing and editing [OpenSCAD](https://openscad.org/) files.

## Overview

OpenSCAD App provides an intuitive interface for working with OpenSCAD, the programmers' solid 3D CAD modeler. It combines a powerful code editor with real-time 3D visualization, making it easier to design and iterate on parametric 3D models.

## Features

- **Visual Editor**: Edit OpenSCAD files with syntax highlighting and code completion
- **3D Preview**: Real-time visualization of your OpenSCAD models
- **File Management**: Open, save, and organize your OpenSCAD projects
- **Cross-Platform**: Works on macOS, Windows, and Linux

## Getting Started

### Prerequisites

- [OpenSCAD](https://openscad.org/downloads.html) installed on your system

### Installation

Clone the repository:

```bash
git clone https://github.com/cedricziel/openscad-app.git
cd openscad-app
```

## Usage

1. Open the application
2. Create a new file or open an existing `.scad` file
3. Edit your OpenSCAD code in the editor
4. View the 3D preview update as you make changes
5. Export your model when ready

## OpenSCAD File Format

OpenSCAD uses a script-based approach to 3D modeling. Here's a simple example:

```openscad
// A simple cube with a cylinder hole
difference() {
    cube([20, 20, 20], center = true);
    cylinder(h = 25, r = 5, center = true);
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source. See the LICENSE file for details.

## Acknowledgments

- [OpenSCAD](https://openscad.org/) - The open-source CAD software this app is built around
- The OpenSCAD community for their excellent documentation and examples
