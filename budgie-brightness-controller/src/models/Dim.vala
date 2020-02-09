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
public class Dim : Flame
{
    public double Blue {get; set;}

    public string MaxBrightnessText
    {
        owned get{return DoubleToString(MaxBrightness, "%.1f");}
    }

    public string BrightnessText
    {
        owned get{return DoubleToString(Brightness, "%.1f");}
    }

    public string BlueText
    {
        owned get{return DoubleToString(Blue, "%.1f");}
    }

    public Dim()
    {
    }
}
}