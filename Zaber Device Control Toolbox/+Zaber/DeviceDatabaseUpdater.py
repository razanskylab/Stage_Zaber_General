# DeviceDatabaseUpdater.py
#
# This Python 3 script will download the Zaber Device Database from the
# Zaber website, decompress it, extract data, output the data to 
# a MATLAB .mat file, generate enumerations for Binary protocol codes,
# then optionally delete the downloaded database file.
#
# The normal invocation is:
# python3 DeviceDatabaseUpdater.py
# This command will download the device database, generate the device
# information .mat file, update the binary command enum constants, and
# then delete the downloaded file. There are optional command-line
# arguments to skip some of these steps; use 
# "python3 DeviceDatabaseUpdater.py --help" to see them.
#
# You may wish to use this script if you want updated data about
# new Zaber products without updating to a new version of the Zaber
# MATLAB toolbox. Otherwise, new versions of the generated data will 
# be published by default with new releases of the Zaber MATLAB toolbox.
# 
# The generated .mat file provides a way for the Zaber MATLAB library
# to look up needed information about Zaber products without users
# having to have the MATLAB Database Toolbox installed. Those who do have
# the Database Toolbox may wish to write their own implementation of the
# Zaber.DeviceDatabase MATLAB class that uses the sqlite3 database directly
# or uses hardcoded data to answer queries, and only use this script to 
# download and decompress the file.
#
# The .mat file produced by this script is only intended for use with
# the Zaber MATLAB library and its content and schema are subject to
# change. If you want a customized .mat file of Zaber device data, you
# are encouraged to modify this file to output the data you want to
# a different .mat file.
#
# This script can also generate MATLAB enumerations from the database
# in order to provide symbolic names for Zaber Binary protocol code
# numbers (ie commands, error codes and status codes). The names of the
# files generated are fixed: BinaryCommandType.m, BinaryErrorType.m 
# and BinaryReplyType.m.
#
# In addition to the base Python 3 distribution, you will also need to
# install the numpy and scipy packages: 'pip install numpy scipy' at 
# the command prompt. If you get a scipy-related error when running this
# script, you may also need to install the Visual C++ 2015 Redistributable
# for your system, which is available at: 
# https://www.microsoft.com/en-us/download/details.aspx?id=48145
#
# NOTE when downloading the device database, this script identifies itself
# to Zaber by setting the user-agent HTTP header. This enables Zaber to
# measure how often this script is used by examining our website logs,
# which will also include the IP address of the computer making the
# request.

# Revision history:
#{
#  2016-10-19: First implementation.
#  2017-01-04: Fixed incorrect unit conversion for velocities.
#              Changed the default behavior to update the device list 
#              and enums, so no arguments are needed for normal use.
#  2018-08-14: Changed command-line arguments so that default behavior
#              is to update everything and options are to opt-out of
#              some update steps.
#              Changed enum generation to merge new values with existing
#              ones if they exist, and to avoid adding new names that 
#              differ only in case from old names.
#              Added use of User-Agent header to enable measurement of
#              how often this script is used.
#}

import argparse
import lzma
import numpy
import os
import re
import scipy.io
import sqlite3
import sys
import tempfile
import urllib.request

# Defaults
gDownloadUrl = "https://www.zaber.com/software/device-database/devices-public.sqlite.lzma"
gInputFilename = "devices-public.sqlite"
gOutputFilename = "DeviceDatabase.mat"


# .mat file schema for the top-level table, keyed by device ID.
sDeviceSchema = [("DeviceId", int),
                 ("Name", object),
                 ("Peripherals", numpy.recarray)
                ]

# .mat file schema for the peripherals field of the device schema above.
sPeripheralSchema = [("PeripheralId", int), 
                     ("Name", object),
                     ("PositionUnitScale", float),
                     ("VelocityUnitScale", float),
                     ("AccelerationUnitScale", float),
                     ("ForceUnitScale", float),
                     ("MotionType", object),
                     ("IsScaleResolutionDependent", bool)
                    ]


def create_command_line_parser():
    """
    Configures a command line argument parser for the script.

    Returns
    -------
    argparse.ArgumentParser: A configured command-line parser.
    """
    global gDownloadUrl, gInputFilename, gOutputFilename

    parser = argparse.ArgumentParser(description = "Download the Zaber Device Database and convert it for use with the Zaber MATLAB library.")
    parser.add_argument("--url", dest = "url", type = str, default = gDownloadUrl, help = "Optional: Specify an alternate URL to download the database from.")
    parser.add_argument("--dbfile", type = str, default = gInputFilename, help = "Optional: Override the default name of the sqlite database file to download to and read from (" + gInputFilename + ").")
    parser.add_argument("--matfile", type = str, default = gOutputFilename, help = "Override the name of the MATLAB .mat device database (" + gOutputFilename + ").")
    parser.add_argument("--download", action = "store_true", help = "Optional: Force re-download of database file even if already present. Default is to use the existing file if present, or download it otherwise.")
    parser.add_argument("--nodelete", action = "store_true", help = "Optional: Keep the downloaded database file(s) after processing is complete. Defaults to false.")
    parser.add_argument("--skipdevices", action = "store_true", help = "Optional: Do not update the device database .mat file. Default is to update the file.")
    parser.add_argument("--skipenums", action = "store_true", help = "Optional: Do not update the binary code enumerations. Default is to update them.")

    return parser


def download_device_database(aUrl, aPath):
    """
    Download a database, decompress it and save to the specified filename.

    Parameters
    ----------
    aUrl: str
        URL to download the database file from.
    aPath: str
        Location to store the downloaded and decompressed file.
    """
    headers = { "User-Agent": "ZaberDeviceControlToolbox/1.2.0 (Python)" }
    request = urllib.request.Request(aUrl, None, headers)
    
    with tempfile.TemporaryFile() as tmpFile:
        with urllib.request.urlopen(request) as response:
            data = response.read()
            tmpFile.write(data)
            
        tmpFile.seek(0)

        print("Decompressing downloaded file...")
        with lzma.open(tmpFile) as ifp:
            data = ifp.read()

    if len(data) < 1:
        raise IOError("Failed to decompress downloaded device database.")

    if os.path.exists(aPath):
        os.remove(aPath)

    with open(aPath, "wb") as ofp:
        ofp.write(data)


def get_dimension_names(aCursor):
    """
    Get the dimension table in indexable form.
    
    Parameters
    ----------
    aCursor: sqlite3 cursor
        Open cursor in the device database.

    Returns
    -------
    str[]: Names of the unit of measure dimensions.
    """
    aCursor.execute("SELECT * FROM Matlab_Dimensions;")
    dimensions = { 0: "none" }
    maxIndex = 0
    for row in aCursor.fetchall():
        id = int(row["Id"])
        name = str(row["Name"])
        dimensions[id] = name
        if (id > maxIndex):
            maxIndex = id;

    result = []
    result.extend(["unknown"] * (maxIndex + 1))
    for (key, value) in iter(dimensions.items()):
        result[key] = value

    return result


def get_device_unit_conversions(aCursor, aDimensionTable, aProductId):
    """
    Determine the physical units of the device.

    Parameters
    ----------
    aCursor: sqlite3 cursor
        Open cursor in the device database.
    aDimensionTable: str[]
        Return value from get_dimension_names().
    aProductId: int or str
        Device or peripheral product ID to get units for.

    Returns
    -------
    6-tuple:
        [0]: int - value matching the MotionType.m enumeration.
        [1]: float - Scale factor for position units to meters or degrees.
        [2]: float - Scale factor for velocity units to meters or degrees
                     per second.
        [3]: float - Scale factor for acceleration units to meters or 
                     degrees per second squared.
        [4]: float - Scale factor for force or torque units to Newtons or 
                     Newton-meters.
        [5]: bool  - True if the position, velocity and acceleration
                     conversions should take resolution into account.
    """

    motionType = 0
    positionScale = 1.0
    velocityScale = 1.0
    accelScale = 1.0
    forceScale = 1.0
    function = "linear-resolution"
    useResolution = False

    aCursor.execute("SELECT * FROM Matlab_ProductsDimensionsFunctions WHERE ProductId = " + str(aProductId) + ";")
    rows = aCursor.fetchall()
    for row in rows:
        dimensionId = int(row["DimensionId"])
        scale = float(row["Scale"])
        function = str(row["FunctionName"]).lower()
        dimensionName = aDimensionTable[dimensionId].lower()
        if (dimensionName in ["length", "angle"]):
            positionScale = scale

            # Every device is expected to have a position function, so only
            # check the motion type once to avoid getting confused by unit
            # conversions for current, percent etc.

            if ("resolution" in function):
                useResolution = True

            # These values have to match the MATLAB Zaber.MotionType enum.
            if ("linear" in function):
                if ("length" == dimensionName) or ("velocity" == dimensionName) or ("acceleration" == dimensionName):
                    motionType = 1 # Linear
                elif ("ang" in dimensionName):
                    motionType = 2 # Rotary
                elif (("none" in dimensionName) or (len(dimensionName) < 1)):
                    motionType = 0 # None
                else:
                    motionType = 9 # Unknown
            elif ("tangential" in function):
                motionType = 3 # Tangential
            else:
                raise KeyError("Unrecognized position unit conversion function " + function)

        elif ("velocity" in dimensionName):
            velocityScale = scale
        elif ("acceleration" in dimensionName):
            accelScale = scale
        elif (dimensionName in ["force", "torque"]):
            forceScale = scale

    return (motionType, positionScale, velocityScale, accelScale, forceScale, useResolution)



def read_device_info(aCursor):
    """
    Extract device data from the database.

    Parameters
    ----------
    aCursor: sqlite3 cursor
        Open cursor in the device database.

    Returns
    -------
    numpy.recarray - Table of device and peripheral properties using
        the schemas defined near the top of this file.
    """

    dimensions = get_dimension_names(aCursor);

    # Get all device IDs and choose only the latest firmware version for each.
    devices = []

    aCursor.execute("SELECT * FROM Matlab_Devices ORDER BY DeviceId, MajorVersion DESC, MinorVersion DESC, Build DESC;")
    rows = aCursor.fetchall()

    if (len(rows) < 1):
        raise IOError("No devices found in this database!")

    currentId = -1
    for row in rows:
        dId = int(row["DeviceId"])
        if (dId != currentId):
            # Only take information from the highest firmware version.
            # The MATLAB toolbox currently does not consider firmware version part of the device identity.
            currentId = dId; 
            # First column is the device ID, second is the device name, third is the primary key.
            devices.append((dId, str(row["Name"]), int(row["Id"])))

    numDevices = len(devices)
    print("Found " + str(numDevices) + " unique device IDs.")
    table = numpy.recarray((numDevices,), dtype=sDeviceSchema)

    for i in range(0, numDevices):
        device = devices[i]
        table[i].DeviceId = device[0]
        table[i].Name = device[1]
        msg = str(device[0]) + " = " + device[1]

        peripherals = []
        
        aCursor.execute("SELECT * FROM Matlab_Peripherals WHERE ParentId = " + str(device[2]) + " ORDER BY PeripheralId;")
        rows = aCursor.fetchall()
        for row in rows:
            # First column is the peripheral ID, second is the peripheral name, third is the primary key.
            peripherals.append((int(row["PeripheralId"]), str(row["Name"]), int(row["Id"])))

        numPeripherals = len(peripherals)
        if (numPeripherals < 1): # Not a controller.
            periTable = numpy.recarray((1,), dtype=sPeripheralSchema)
            periTable[0].PeripheralId = 0
            periTable[0].Name = ""
            
            unit = get_device_unit_conversions(aCursor, dimensions, device[2])
            periTable[0].MotionType = unit[0]
            periTable[0].PositionUnitScale = unit[1]
            periTable[0].VelocityUnitScale = unit[2]
            periTable[0].AccelerationUnitScale = unit[3]
            periTable[0].ForceUnitScale = unit[4]
            periTable[0].IsScaleResolutionDependent = unit[5]
        else:
            msg += " + " + str(numPeripherals) + " peripherals:"
            periTable = numpy.recarray((numPeripherals,), dtype=sPeripheralSchema)
            for j in range(0, numPeripherals):
                peripheral = peripherals[j]
                periTable[j].PeripheralId = peripheral[0]
                periTable[j].Name = peripheral[1]
                msg += "\n- " + str(periTable[j].PeripheralId) + " = " + str(periTable[j].Name)
            
                unit = get_device_unit_conversions(aCursor, dimensions, peripheral[2])
                periTable[j].MotionType = unit[0]
                periTable[j].PositionUnitScale = unit[1]
                periTable[j].VelocityUnitScale = unit[2]
                periTable[j].AccelerationUnitScale = unit[3]
                periTable[j].ForceUnitScale = unit[4]
                periTable[j].IsScaleResolutionDependent = unit[5]

        table[i].Peripherals = periTable

        print(msg)

    return table


def get_binary_enum_values(aCursor):
    """
    Find binary command names and values.

    Parameters
    ----------
    aCursor: sqlite3 cursor
        Open cursor in the device database.

    Returns
    -------
    dict - ["commands"] - Array of 2-tuples listing all known binary
                          commands. First entry is an int giving the 
                          command number. Second entry is a string giving
                          the name of the command.
           ["replies"]  - Array of 2-tuples containing the numeric codes
                          and names of all known binary reply types.
           ["errors"]   - Array of 2-tuples containing the numeric codes
                          and names of all known binary error codes.
    """
    result = {}

    commands = []
    aCursor.execute("SELECT * FROM Matlab_BinaryCommands;")
    rows = aCursor.fetchall()
    for row in rows:
        commands.append((row["Command"], row["Name"]))

    aCursor.execute("SELECT * FROM Matlab_BinarySettings WHERE ReturnCommand NOT NULL;")
    rows = aCursor.fetchall()
    for row in rows:
        commands.append((row["ReturnCommand"], "Return " + row["Name"]))

    aCursor.execute("SELECT * FROM Matlab_BinarySettings WHERE SetCommand NOT NULL;")
    rows = aCursor.fetchall()
    for row in rows:
        commands.append((row["SetCommand"], "Set " + row["Name"]))

    result["commands"] = sorted(commands, key=lambda item: item[1])
    
    replies = []
    aCursor.execute("SELECT * FROM Matlab_BinaryReplies;")
    rows = aCursor.fetchall()
    for row in rows:
        replies.append((row["Reply"], row["Name"]))

    result["replies"] = sorted(replies, key=lambda item: item[1])

    errors = []

    aCursor.execute("SELECT * FROM Matlab_BinaryErrors;")
    rows = aCursor.fetchall()
    for row in rows:
        errors.append((row["Code"], row["Name"]))

    result["errors"] = sorted(errors, key=lambda item: item[1])

    return result


def read_binary_enum_file(aPath):
    """
    Load the meaningful content of an existing Matlab binary enum
    file. This is done to ensure that legacy values are preserved
    with their original casing.

    Parameters
    ----------
    aPath: str
        Path to the file to read in.

    Returns
    ----------
    Array - 2-tuples read from the file. First element is the name of the
            enum value and the second element is the value as an int.
            Note there may be multiple instances of the same number.
    """
    result = []

    r = re.compile("^\s+([^\s]+)\s+\((\d+)\)")
    with open(aPath, "rt") as fp:
        for line in fp.readlines():
            match = r.match(line)
            if match:
                groups = match.groups()
                if (len(groups) == 2):
                    name = groups[0]
                    val = int(groups[1])
                    result.append((name, val))

    return result


def write_binary_enum_file(aCodeTable, aEnumName, aBaseType):
    """
    Generate a .m file defining an enumeration for binary protocol
    command, reply or error type values. This overwrites any existing
    file.

    If there is an existing file, its content is first reloaded and
    used to preserve casing of existing names. If the new content has
    a same numeric value as the old content but with the name differing
    only in casing, the old name is preserved and the new name ignored.
    Otherwise the new name is added with a duplicate value and the old
    name and value are kept.

    Parameters
    ----------
    aCodeTable: Array
        List of (value, name) pairs to convert into an enum.
    aEnumName: str
        Name of the enum to generate. ".m" is added to this to generate
        the file name as well.
    aBaseType: str
        Name of the base data type for the enum, ie "uint8".
    """

    valuesbyName = dict()
    namesByValue = dict()

    filename = aEnumName + ".m"
    print("Generating " + filename + "...")
    if (os.path.exists(filename)):
        valuesByName = dict(read_binary_enum_file(filename))
        for (name, code) in valuesByName.items():
            namesByValue.setdefault(code, [])
            namesByValue[code].append(name)

        os.remove(filename)

    # Merge old names with new names.
    for (code, rawName) in aCodeTable:
        name = rawName.replace(" ", "_").replace("-", "_")
        if code not in namesByValue:
            # New enum value case.
            namesByValue.setdefault(code, [])
            namesByValue[code].append(name)
            # Print a warning if the name already existed.
            if name in valuesByName:
                print("WARNING: Value of '%s' has changed!" % name)
            valuesByName[name] = code
        else:
            # Numeric value previously existed - use old name if the new 
            # name is the case-insensitively the same. Else duplicate it.
            oldNameMatches = False
            for oldName in namesByValue[code]:
                if (oldName.lower() == name.lower()):
                    oldNameMatches = True
                    break

            if (not oldNameMatches):
                namesByValue[code].append(name)
                if ((name in valuesByName) and (code != valuesByName[name])):
                    print("WARNING: Value of '%s' has changed!" % name)
                valuesByName[name] = code

    maxLength = 1
    for name in valuesByName.keys():
        maxLength = max(maxLength, len(name))

    generatedNames = set()
    with open(filename, "wt") as fp:
        fp.write("%%   %s Enumeration to assist with interpreting Zaber Binary protocol codes.\n\n" % (aEnumName.upper()))
        fp.write("%   THIS IS A GENERATED FILE - DO NOT EDIT. See DeviceDatabaseUpdater.py.\n\n")
        fp.write("classdef %s < %s\n" % (aEnumName, aBaseType))
        fp.write("    enumeration\n")

        first = True
        sortedNames = sorted(valuesByName.keys())
        for name in sortedNames:
            code = valuesByName[name]
            if name not in generatedNames:
                generatedNames.add(name)
                if not first:
                    fp.write(",\n")
                first = False
                fp.write("        %s (%d)" % (name.ljust(maxLength, " "), code))
        fp.write("\n")

        fp.write("    end\n")
        fp.write("end\n")


def run(aArgs):
    """
    Main routine for this script. 

    Parameters
    ----------
    aArgs: argparser args struct.
    """
    global gDownloadUrl, gInputFilename, gOutputFilename

    gDownloadUrl = args.url
    gInputFilename = args.dbfile
    gOutputFilename = args.matfile

    doDownload = args.download
    doDelete = not args.nodelete
    doOutputMatrix = not args.skipdevices
    doOutputEnums = not args.skipenums

    if os.path.isfile(gInputFilename):
        if (not doDownload):
            print("Database file already exists; will not delete it.")
            doDelete = False
    else:
        print("Database download forced because file " + gInputFilename + " does not exist.")
        doDownload = True

    if doDownload:
        print("Downloading device database from: " + gDownloadUrl)
        download_device_database(gDownloadUrl, gInputFilename)

    print("Reading database " + gInputFilename + " (might take a while)...")
    connection = sqlite3.connect(gInputFilename)
    connection.row_factory = sqlite3.Row
    cursor = connection.cursor()

    # Save the database to the .mat file.
    if (doOutputMatrix):

        table = read_device_info(cursor)
        print("Saving device database data to " + gOutputFilename)
        scipy.io.savemat(gOutputFilename, { "devices" : table })

    # Generate the binary command list.
    if (doOutputEnums):
        enums = get_binary_enum_values(cursor)
        write_binary_enum_file(enums["commands"], "BinaryCommandType", "uint8");
        write_binary_enum_file(enums["replies"], "BinaryReplyType", "uint8");
        write_binary_enum_file(enums["errors"], "BinaryErrorType", "int32");

    connection.close()

    # Optionally delete the downloaded file.
    if doDelete:
        print("Removing downloaded file " + gInputFilename)
        os.remove(gInputFilename)


if (__name__ == "__main__"):
    parser = create_command_line_parser()
    args = parser.parse_args()
    run(args)
