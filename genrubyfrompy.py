#!/usr/bin/python

import pprint
import os
import sys
import re
import time
from string import Template
from collections import OrderedDict

sys.path.append(os.path.dirname(os.path.realpath(__file__)) + '/pysdk')
from insieme.pymit.pyaccess import PyClassDirectory


def rubyClassName(className):
    rubyname = list(className)
    if len(rubyname) > 0:
        rubyname[0] = rubyname[0].upper()
    if '.' in rubyname:
        rubyname.remove('.')
    return ''.join(rubyname)


def getChildren(pyClassDict):
    return [rubyClassName(x[0]) for x in pyClassDict['_children'].items()]


def getProps(pyClassDict):
    # {
    #     'test' => {'isAdmin' => true}, 'test2' => {'isAdmin'=> true}
    # }
    prop_entries = []
    flags_list = ['isAdmin', 'isImplicit', 'isCreateOnly', 'isDn', 'isRn', 'isExplicit']

    for prop, flags in pyClassDict['_props'].items():
        propflags = []
        for flag in flags_list:
            if hasattr(flags, '_{}'.format(flag)):
                bo0l = 'true' if getattr(flags, '_{}'.format(flag)) else 'false'
                propflags.append("'{}' => {}".format(flag, bo0l))
        prop_entries.append("'{}' => {{ {} }}".format(prop, ', '.join(propflags)))
    return '{{ {} }}'.format(',\n'.join(prop_entries))
    # entries = ["%s => {".format(cls, props.get('isAdmin')) for cls,props in pyClassDict['_props'].items()]


def getNamingProps(pyClassDict):
    return pyClassDict['_orderedNamingProps']


def getContainers(pyClassDict):
    return [rubyClassName(x[0]) for x in pyClassDict['_containers'].items()]
    # return ', '.join('\'%s\'' % c for c in pyClassDict['_containers'].keys())


def getRnFormatAsRuby(pyClassDict):
    a = pyClassDict['_rnFormat']
    return '\'%s\'' % re.sub(
        '\%\(([a-zA-Z]+)\)s', '\' << @attributes[\'\\1\'] << \'', a)


def getRnFunc(pyClassDict):
    '''
    Generates the logic to create the relative name for the object, based on the rnPrefixes and orderedNames
    '''
    # if len(pyClassDict['_orderedNamingProps']) == 0:
    #     rnFunc = 'self.class.prefix'
    # elif len(pyClassDict['_orderedNamingProps']) == len(pyClassDict['_rnPrefixes']):
    #     rnFunc = ' + '.join("'%s' + @options[:%s]" % t for t in zip(getRnPrefixes(pyClassDict), pyClassDict['_orderedNamingProps']))
    # else:
    #     rnFunc = getRnFormatAsRuby(pyClassDict)
    # print 'len of rnPrefixes is %d' % len(pyClassDict['_rnPrefixes'])
    # print 'len of naming props is %d' % len(pyClassDict['_orderedNamingProps'])
    # pprint.pprint(pyClassDict)
    # sys.exit(0)
    # rnFunc = 'self.class.prefix'
    rnFunc = getRnFormatAsRuby(pyClassDict)
    return rnFunc


def getRnPrefixes(pyClassDict):
    if len(pyClassDict['_rnPrefixes']) > 0:
        return ', '.join(['[\'{0}\', {1}]'.format(x[0], str(x[1]).lower()) for x in pyClassDict['_rnPrefixes']])
    else:
        return ''


def getLabel(pyClassDict):
    return pyClassDict['_label']


def getRnPrefix(pyClassDict):
    if len(pyClassDict['_rnPrefixes']) > 0:
        # if len(pyClassDict['_rnPrefixes']) > 1:
            # print '%s has %d rnPrefixes' % (pyClassDict['_name'],
            # len(pyClassDict['_rnPrefixes']))
        return pyClassDict['_rnPrefixes'][0][0]
    else:
        return ''


def getClassName(pyClassDict):
    return pyClassDict['_name']


def getRnFormat(pyClassDict):
    return pyClassDict['_rnFormat']

def getReadOnly(pyClassDict):
    return 'true' if pyClassDict['_isReadOnly'] else 'false'

def getRubyClassMap(classMap):
    rubyCode = Template("""# auto-generated code
module ACIrb
  CLASSMAP = Hash.new 'None'
  $classMap
  def lookupClass(classname)
    return CLASSMAP[classname]
  end
end
    """)
    vals = dict(
        classMap='\n  '.join(
            ['CLASSMAP[\'{0}\'] = \'{1}\''.format(k, v) for k, v in classMap.items()]),
    )

    return rubyCode.substitute(vals)

def getRubyClass(pyClassDict):
    rubyCode = Template("""  class $rubyClassName < MO
    @class_name = '$objectName'
    @ruby_class = '$rubyClassName'
    @prefix = '$prefix'
    @prefixes = [$prefixes]
    @rn_format = '$rnFormat'
    @containers = $containers
    @props = $props
    @child_classes = $children
    @label = '$label'
    @naming_props = $namingProps
    @read_only = $readOnly

    def rn
      $rn
    end
  end
""")
    vals = dict(rubyClassName=rubyClassName(pyClassDict['_name']),
                objectName=getClassName(pyClassDict),
                prefix=getRnPrefix(pyClassDict),
                prefixes=getRnPrefixes(pyClassDict),
                rnFormat=getRnFormat(pyClassDict),
                containers=getContainers(pyClassDict),
                props=getProps(pyClassDict),
                children=getChildren(pyClassDict),
                rn=getRnFunc(pyClassDict),
                label=getLabel(pyClassDict),
                namingProps=getNamingProps(pyClassDict),
                classNameShort=getClassName(pyClassDict).replace('.', ''),
                readOnly=getReadOnly(pyClassDict),
                )
    return rubyCode.substitute(vals)


def getRubyPackage(classDef):
    rubyCode = Template("""# auto-generated code
require 'mo'
module ACIrb
$rubyClasses
end
""")
    vals = dict(rubyClasses=classDef,
                )
    return rubyCode.substitute(vals)


def getRubyAutoLoad(autoLoaderMap):

    rubyAutoLoad = '\n'.join(['  ACIrb.autoload(\'{0}\', \'ACIrb/{1}\')'.format(
        rubyClass, rubyFile) for rubyClass, rubyFile in autoLoaderMap.items()])

    rubyCode = Template("""# auto-generated code
module ACIrb
$rubyAutoLoad
end
""")
    vals = dict(rubyAutoLoad=rubyAutoLoad,
                )
    return rubyCode.substitute(vals)


def prettyprint(item, depth=0):
    if getattr(item, '__dict__', None):
        prettyprint(item.__dict__, depth + 1)
    elif isinstance(item, list):
        for i in item:
            print '-' * depth, type(i), i
    elif isinstance(item, set):
        for i in item:
            print '-' * depth, type(i), i
    elif isinstance(item, dict):
        for k, v in item.items():
            print '-' * depth, k, ':'
            prettyprint(v, depth + 1)
    else:
        print '-' * depth, type(item), item


def generateRuby(classdir):
    classMap = OrderedDict()
    packages = OrderedDict()
    '''
    packages will be a dict of format:
    {
        packageName: (pkgCode (str), pkgClasses (list))
    }
    '''

    for item in classdir.getClasses():
        pkgName = getClassName(item.__dict__).split('.')[0]
        className = getClassName(item.__dict__).replace('.', '')
        rubyName = rubyClassName(item.__dict__['_name'])

        classMap[className] = rubyName
        pkgCode, pkgClasses = packages.get(pkgName, ('', []))
        pkgCode = pkgCode + getRubyClass(item.__dict__)
        pkgClasses.append(rubyName)
        packages[pkgName] = (pkgCode, pkgClasses)

    autoLoaderMap = OrderedDict()

    directory = os.path.join(
        os.path.abspath(
            os.path.dirname(__file__)),
        'lib',
        'ACIrb')

    if not os.path.exists(directory):
        os.makedirs(directory)

    for pkgname, payload in packages.items():

        pkgCode, pkgClasses = payload

        for pkgClass in pkgClasses:
            autoLoaderMap[pkgClass] = '{0}.rb'.format(pkgname)

        fileName = os.path.join(
            os.path.abspath(
                os.path.dirname(__file__)),
            'lib',
            'ACIrb',
            pkgname +
            '.rb')

        # Create the package 
        with open(fileName, 'w') as f:
            r = getRubyPackage(pkgCode)
            f.write(r)

    # Create the lookup map
    fileName = os.path.join(
        os.path.abspath(
            os.path.dirname(__file__)),
        'lib',
        'lookup.rb')
    with open(fileName, 'w') as f:
        f.write(getRubyClassMap(classMap))

    # Create the autoloader
    fileName = os.path.join(
        os.path.abspath(
            os.path.dirname(__file__)),
        'lib',
        'autoloadmap.rb')
    with open(fileName, 'w') as f:
        f.write(getRubyAutoLoad(autoLoaderMap))


def main():
    start = time.time()
    classdir = PyClassDirectory()
    generateRuby(classdir)
    print 'Completed in %.2f seconds' % (time.time() - start)

if __name__ == '__main__':
    main()
