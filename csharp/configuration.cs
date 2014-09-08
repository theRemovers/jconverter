public enum Output { Rgb16, Cry16 };

public class Configuration {
  public Output output_format;
  public bool dithering;
  public bool ascii_output;
  public string target_dir;

  public bool clut_mode;
  public bool opt_clut;

  public bool force_bpp;
  public int forced_bpp;

  public bool mode15bit;
  public bool rgb24mode;
  public bool gray;
  public bool texture;
  public bool keep_negative;
  public bool keep_positive;
  public bool overwrite;

  public bool rotate;
  public int rotate_angle;

  public bool cut;
  public int cut_x;
  public int cut_y;
  public int cut_w;
  public int cut_h;

  public bool use_tga2cry;

  public bool sample;
  public int sample_w;
  public int sample_h;

  public bool aworld;

  public bool header;

  public Configuration() {
    this.output_format = Output.Rgb16;
    this.dithering = false;
    this.ascii_output = true;
    this.target_dir = "./";
  }

  override public string ToString() {
    System.Text.StringBuilder buf = new System.Text.StringBuilder();

    switch(this.output_format) {
    case Output.Rgb16:
      buf.Append("-rgb");
      break;
    case Output.Cry16:
      buf.Append("-cry");
      break;
    }
    buf.Append(' ');

    buf.Append(this.dithering ? "--dithering" : "--no-dithering");
    buf.Append(' ');

    buf.Append(this.ascii_output ? "--ascii" : "--binary");
    buf.Append(' ');

    buf.Append("--target-dir ");
    buf.Append(this.target_dir);
    buf.Append(' ');

    return buf.ToString();
  }
}
