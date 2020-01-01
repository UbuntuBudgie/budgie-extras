/*
 * BrightnessController 
 * This file is part of UbuntuBudgie
 * 
 * Author: Serdar ŞEN github.com/serdarsen
 * 
 * Copyright © 2018-2020 Ubuntu Budgie Developers
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */
 
namespace BrightnessController.Models 
{
public class Flame
{
    public string Name {get; set;}
    public double MaxBrightness {get; set;}
    public double Brightness {get; set;}
    public bool IsActive {get; set;}

    public Flame()
    {
    }

    protected string DoubleToString(double num, string format)
    {
        char[] buf = new char[double.DTOSTR_BUF_SIZE];
        var str = num.format(buf, format);

        return str;
    }
}
}