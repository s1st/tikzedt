﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Windows;
using System.IO;
using System.Diagnostics;
using System.Media;
using System.Windows.Threading;
//using System.Drawing;

namespace TikzEdt
{
    static class Consts
    {
        public const float cmperin = 2.54F;
        public const float ptspertikzunit = 72.0F / cmperin;
        public const float TikzDefaultLinewidth = 0;
        public const string TikzDefaultFont = "Times";
        public const float TikzDefaultFontSize = 8F;
        public const int TikzImgResolution = 300; // resolution in dpi with which images are compiled

        public static string[] TikzArrowTipCodes = new string[] { "", ">", "<" };
        //public static DashStyle[] TikzToSystemDashStyle = new DashStyle[] { DashStyle.Solid, DashStyle.Dot, DashStyle.Dash };
        public static float[][] TikzToSystemDashPattern = new float[][] {
            new float[]{0.1F}, new float[]{.1F,.1F}, new float[]{.2F,.1F}
        };

        public const string cSettingsFile = "T2Gsettings.xml";
        public const string cSyntaxFile = "TikzSyntax.xshd";
        public const string cMRUFile = "T2GMRU.xml";
        public const int MaxMRU = 10;
        public const string cStyleRepoFile = "StyleRepo.dat";

        public const string CoordinateVertexStyleName = "helper";

        public const string DoubleFormat = "#.####";

        public const float selecttoler = .01F;
        public const float drawXsize = .1F; // drawn for invisible vertices
        public const float coordvertexsize = .25F; // size of size zero vertex (to ease selection)

        //const string cLatex = "Pdflatex";
        //string cLatexPath = "pdflatex"; //@"C:\Program Files\MiKTeX 2.8\miktex\bin\pdfplatex.exe";
        public const string cTempFile = "temp_preview";         // for preview
        public const string cTempImgFile = "temp_previewtexts"; // for equation rendering
        public const string defaultCurFile = "<new graph>";
        public const string PreviewHeader =
        @"\documentclass[fleqn]{article}
\usepackage{tikz,amsmath, amssymb,bm,color}
\usepackage[margin=0cm,nohead]{geometry}
";

        public const string ImgHeader =
        @"\documentclass[fleqn]{article}
\usepackage{amsmath, amssymb,bm,color}
";

        public const string precompilation_args = "-ini -job-name=\"" + cTempFile + "\" \"&pdflatex " + cTempFile + "pre.tex\\dump\"";
        public const string precompilation_args_img = "-ini -job-name=\"" + cTempImgFile + "\" \"&latex " + cTempImgFile + "pre.tex\\dump\"";


    }

    static class Helper
    {

        public static void GeneratePrecompiledHeaders()
        {
            StreamWriter s = new StreamWriter(Consts.cTempImgFile + "pre.tex");
            s.WriteLine(Consts.ImgHeader);
            s.Close();

            System.Diagnostics.Process p = new System.Diagnostics.Process();
            System.Diagnostics.ProcessStartInfo psi = new System.Diagnostics.ProcessStartInfo("latex");
            psi.Arguments = Consts.precompilation_args_img;
            psi.CreateNoWindow = true;
            p.StartInfo = psi;
            p.Start();

            s = new StreamWriter(Consts.cTempFile + "pre.tex");
            s.WriteLine(Consts.PreviewHeader);
            s.Close();

            p = new System.Diagnostics.Process();
            psi = new System.Diagnostics.ProcessStartInfo("pdflatex");
            psi.Arguments = Consts.precompilation_args;
            psi.CreateNoWindow = true;
            p.StartInfo = psi;
            p.Start();
        }

    }

    public class BBGatherer
    {
        public Rect r;
        public void Add(Point p)
        {
            if (r == null)
            {
                r = new Rect(p.X, p.Y, 0, 0);
            }
            else
            {
                r = Rect.Union(r, p);
            }
        }
        public void Add(Rect tr)
        {
            if (r == null)
            {
                r = tr;
            }
            else
            {
                r = Rect.Union(r, tr);
            }
        }
        public Rect GetRect(double margin)
        {
            return Rect.Inflate(r, margin, margin);
            //.new Rect(r.X - margin, r.Y - margin, r.Width + 2 * margin, r.Height + 2 * margin);
            //return rr;
        }
    }

    public static class Rasterizer
    {

        public static Point rasterizeEucl(Point p, double GridWidth, Rect BB)
        {
            return new Point(Math.Round(p.X / GridWidth) * GridWidth, Math.Round(p.Y / GridWidth) * GridWidth);
        }
        // input: p in Eucl. coordinates
        //public static Point rasterizePolar(Point p, Point center, double rstep, int nsectors)
        //{
        //Point pp = Point.eucltopolar(p, center);
        //pp.X = Math.Round(pp.X / rstep) * rstep;
        //pp.Y = Math.Round(pp.Y * nsectors / (2 * Math.PI)) * 2 * Math.PI / nsectors;
        //return Point.polartoeucl(pp, center);
        //}

    }

    public class TikzToBMPFactory
    {
        public double timeout = 10; //seconds, not impl.
        public double Resolution = 50;
        public struct Job
        {
            public string code, path;
            public Rect BB;
            public Job(string tcode, string tpath, Rect tBB)
            {
                code = tcode; path = tpath; BB = tBB;
            }
        }
        public Queue<Job> todo_tex = new Queue<Job>();
        /// <summary>
        /// 
        /// </summary>
        /// <param name="code">Tikz Code to compile</param>
        /// <param name="path">Path, without ending, e.g. img\myfile </param>
        /// <param name="BB">The bounding box</param>
        public void AddJob(string code, string path, Rect BB)
        {
            todo_tex.Enqueue(new Job(code, path, BB));
            if (!isRunning)
                doCompile();
        }

        protected Process texProcess = new Process();
        protected bool isRunning = false;
        PDFLibNet.PDFWrapper mypdfDoc = null;
        System.Windows.Forms.Control dummy = new System.Windows.Forms.Control();

        /// <summary>
        /// If the compilation gets stuck (actually it shouldn't), 
        /// one can call this method to kill the pdflatex-process.
        /// </summary>
        public void AbortCompilation()
        {
            if (!texProcess.HasExited)
                texProcess.Kill();
        }

        /// <summary>
        /// The main routine, starts the compilation of the Tikz-Picture.
        /// If necessary it initiates compilation of the precompiled headers.
        /// </summary>
        protected void doCompile()
        {
            if (isRunning || todo_tex.Count == 0)
            {
                return;
            }
            isRunning = true;
            Job job = todo_tex.Peek();

            if (!File.Exists(Consts.cTempFile + ".fmt")) // TODO.... not in right folder
            {
                Helper.GeneratePrecompiledHeaders();
                return;
            }

            // save into temporary textfile
            // add bounding box
            bool lsucceeded;
            string codetowrite = writeBBtoTikz(job.code, job.BB, out lsucceeded);

            StreamWriter s = new StreamWriter(job.path + ".tex");
            s.WriteLine(@"%&" + Consts.cTempFile);

            if (lsucceeded)
            {
                s.WriteLine(@"\pdfpageattr{/MediaBox [0 0 " + Convert.ToInt32(job.BB.Width * Consts.ptspertikzunit) + " "
                                                            + Convert.ToInt32(job.BB.Height * Consts.ptspertikzunit) + "]}");
                s.WriteLine(@"\begin{document}");
                s.WriteLine(@"\thispagestyle{empty}");
                s.WriteLine(@"\mathindent0cm \parindent0cm");
                s.WriteLine(@"not seen");
                s.WriteLine(@"\vfill");
            }
            else
            {
                s.WriteLine(@"\begin{document}");
                s.WriteLine(@"\thispagestyle{empty}");
                s.WriteLine(@"\mathindent0cm \parindent0cm");
            }

            s.WriteLine(codetowrite);
            s.WriteLine(@"\end{document}");
            s.Close();

            // call pdflatex         
            texProcess.StartInfo.Arguments = "-quiet -halt-on-error " + "\"" +job.path +"\"" + ".tex";
            texProcess.Start();
        }
        /// <summary>
        /// Adds a rectangle to the Tikzcode in the size specified by BB. 
        /// The rectangle is added as the last command before the \end{tikzpicture} 
        /// </summary>
        /// <param name="code">The Tikz Code. Must contain an "\end{tikzpicture}" </param>
        /// <param name="BB">The bounding box (= size of rectangle to be written) </param>
        /// <param name="succeeded">Returns success, i.e., whether the string "\end{tikzpicture}" has been found</param>
        /// <returns>The Tikzcode, with the "\draw rectangle ...." inserted </returns>
        string writeBBtoTikz(string code, Rect BB, out bool succeeded)
        {
            // hack
            string cend = @"\end{tikzpicture}";
            string[] tok = code.Split(new string[] { cend }, StringSplitOptions.None);
            succeeded = (tok.Length == 2 && BB.Width * BB.Height > 0);
            if (succeeded)
                return tok[0] + @"\draw (" + BB.X + "," + BB.Y + ") rectangle (" + (BB.X + BB.Width).ToString() + "," + (BB.Y + BB.Height).ToString() + "); " + cend + tok[1];
            else
                return code;
        }

        public TikzToBMPFactory()
        {

            texProcess.EnableRaisingEvents = true;
            //texProcess.StartInfo.Arguments = "-quiet -halt-on-error " + Consts.cTempFile + ".tex";
            texProcess.StartInfo.FileName = "pdflatex";
            texProcess.StartInfo.CreateNoWindow = true;
            texProcess.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
            // texProcess.SynchronizingObject = (System.ComponentModel.ISynchronizeInvoke) this;
            texProcess.Exited += new EventHandler(texProcess_Exited);

        }

        /// <summary>
        /// Reload the PDF file. This is called only when the pdf file changes on disk.
        /// It is not called, for example, when the pdf just needs to be redrawn, e.g., due to 
        /// a changed display size.
        /// </summary>
        void RefreshPDF()
        {

        }

        /// <summary>
        /// This is called when PDFLatex has exited
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        void texProcess_Exited(object sender, EventArgs e)
        {
            // HACK: make thread-safe
            //Dispatcher.Invoke(new Action(
            //delegate()
            //{
                Job job = todo_tex.Dequeue();

                if (texProcess.ExitCode == 0)
                {
                    if (mypdfDoc != null)
                        mypdfDoc.Dispose();
                    mypdfDoc = new PDFLibNet.PDFWrapper();
                    mypdfDoc.UseMuPDF = true;
                    if (!mypdfDoc.LoadPDF(job.path + ".pdf"))
                        MessageBox.Show("Couldn't load pdf");

                    double magicnumber = 0.45;
                    dummy.Width = Convert.ToInt32(job.BB.Width * Resolution / magicnumber);
                    dummy.Height = Convert.ToInt32(job.BB.Height * Resolution / magicnumber);

                    mypdfDoc.FitToWidth(dummy.Handle);
                    mypdfDoc.RenderPage(dummy.Handle);
                    dummy.Width = Convert.ToInt32(job.BB.Width * Resolution);
                    dummy.Height = Convert.ToInt32(job.BB.Height * Resolution);

                    if (!(dummy.Width <= 0 || dummy.Height <= 0)) // TODO: this hould nott be necessary
                    {

                        System.Drawing.Bitmap b = new System.Drawing.Bitmap(dummy.Width, dummy.Height);
                        System.Drawing.Graphics gr = System.Drawing.Graphics.FromImage(b);
                        mypdfDoc.ClientBounds = new System.Drawing.Rectangle(0, 0, b.Width, b.Height);
                        mypdfDoc.DrawPageHDC(gr.GetHdc());
                        gr.ReleaseHdc();
                        b.Save(job.path + ".bmp");

                    }
                }
                else ;


                isRunning = false;
                if (todo_tex.Count > 0)
                    doCompile();
            //}
           // ));
        }

    }


}