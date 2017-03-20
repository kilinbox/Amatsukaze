﻿using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Amatsukaze.Server
{
    public enum LaunchType {
        Standalone,
        Server,
        Client
    };

    public class GUIOPtion
    {
        public LaunchType LaunchType = LaunchType.Standalone;
        public int ServerPort = 32768;

        public GUIOPtion(string[] args)
        {
            for (int i = 1; i < args.Length; ++i)
            {
                string arg = args[i];
                if (arg == "-p" || arg == "--port")
                {
                    ServerPort = int.Parse(args[i + 1]);
                    ++i;
                }
                else if(arg == "-l" || arg == "--launch")
                {
                    string opt = args[i + 1];
                    if (opt == "standalone")
                    {
                        LaunchType = LaunchType.Standalone;
                    }
                    else if (opt == "server")
                    {
                        LaunchType = LaunchType.Server;
                    }
                    else
                    {
                        LaunchType = LaunchType.Client;
                    }
                }
            }
        }
    }

    public class Debug
    {
        [Conditional("DEBUG")]
        public static void Print(string str)
        {
            Util.AddLog(str);
        }
    }

    public static class Util
    {
        public static List<Action<string>> LogHandlers = new List<Action<string>>();

        public static void AddLog(string log)
        {
            foreach (var handler in LogHandlers)
            {
                handler(log);
            }
        }

        public static async void AttachHandler(this Task task)
        {
            try
            {
                await task;
            }
            catch (Exception e)
            {
                AddLog(e.Message);
            }
        }

        public static string ToGUIString(this DateTime dt)
        {
            return dt.ToString("yyyy/MM/dd HH:mm:ss");
        }

        public static string ToGUIString(this TimeSpan ts)
        {
            return (int)ts.TotalHours + "時間" + ts.ToString("mm\\分ss\\秒");
        }

        [return: MarshalAs(UnmanagedType.Bool)]
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool GetDiskFreeSpaceEx(
            string lpDirectoryName, 
            out ulong lpFreeBytesAvailable, 
            out ulong lpTotalNumberOfBytes, 
            out ulong lpTotalNumberOfFreeBytes);
    }

    public abstract class ConsoleTextBase
    {
        public abstract void OnAddLine(string text);
        public abstract void OnReplaceLine(string text);

        private List<byte> rawtext = new List<byte>();
        private bool isCR = false;

        public void Clear()
        {
            rawtext.Clear();
            isCR = false;
        }

        public void AddBytes(byte[] buf, int offset, int count)
        {
            for (int i = 0; i < count; ++i)
            {
                if (buf[i] == '\n' || buf[i] == '\r')
                {
                    if (rawtext.Count > 0)
                    {
                        string text = Encoding.Default.GetString(rawtext.ToArray());
                        if (isCR)
                        {
                            OnReplaceLine(text);
                        }
                        else
                        {
                            OnAddLine(text);
                        }
                        rawtext.Clear();
                    }
                    isCR = (buf[i] == '\r');
                }
                else
                {
                    rawtext.Add(buf[i]);
                }
            }
        }
    }
}