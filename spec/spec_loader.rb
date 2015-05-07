require 'simplecov'
SimpleCov.start
require 'acirb'

RSpec.describe 'ACIrb Loader' do
  it 'Verifies the to_s method works' do
    xml = '<topRoot><polUni><fvTenant name="test"/></polUni></topRoot>'
    mo = ACIrb::Loader.load_xml_str(xml)
    puts mo
  end

  it 'Loads MO from XML under topRoot' do
    xml = '<topRoot><polUni><fvTenant name="test"/></polUni></topRoot>'
    mo = ACIrb::Loader.load_xml_str(xml)

    expect(mo.children[0].dn).to eq('uni')
    expect(mo.children[0].mo_type).to eq('polUni')
    expect(mo.children[0].children[0].dn).to eq('uni/tn-test')
    expect(mo.children[0].children[0].rn).to eq('tn-test')
    expect(mo.children[0].children[0].mo_type).to eq('fvTenant')
    expect(mo.children[0].children[0].name).to eq('test')
    expect(mo.root.mo_type).to eq('topRoot')
  end

  it 'Loads MO from XML under polUni' do
    xml = '<polUni><fvTenant name="test"/></polUni>'
    mo = ACIrb::Loader.load_xml_str(xml)
    expect(mo.dn).to eq('uni')
    expect(mo.children[0].dn).to eq('uni/tn-test')
  end

  it 'Loads MO from XML under specific object with dn' do
    xml = '<fvTenant name="test" dn="uni/tn-test"><fvAp name="app1"/></fvTenant>'
    mo = ACIrb::Loader.load_xml_str(xml)
    expect(mo.dn).to eq('uni/tn-test')
  end

  it 'Loads MO from Hash under topRoot' do
    hash = {
      'topRoot' => {
        'children' => [
          {
            'polUni' => {
              'children' => [
                {
                  'fvTenant' => {
                    'children' => [
                      {
                        'fvAp' => {
                          'attributes' => {
                            'name' => 'WebApplication'
                          },
                          'children' => [
                            {
                              'fvAEPg' => {
                                'attributes' => {
                                  'name' => 'WebTier'
                                }
                              }
                            }
                          ]
                        }
                      }
                    ],
                    'attributes' => {
                      'name' => 'test'
                    }
                  }
                },
                {
                  'fvTenant' => {
                    'attributes' => {
                      'name' => 'test2'
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }

    mo = ACIrb::Loader.load_hash(hash)
    expect(mo.dn).to eq('')
    expect(mo.children[0].dn).to eq('uni')
    expect(mo.children[0].children[0].dn).to eq('uni/tn-test')
    expect(mo.children[0].children[1].dn).to eq('uni/tn-test2')
  end

  it 'Loads MO from Hash under polUni' do
    hash = {
      'polUni' => {
        'children' => [
          {
            'fvTenant' => {
              'children' => [
                {
                  'fvAp' => {
                    'attributes' => {
                      'name' => 'WebApplication'
                    },
                    'children' => [
                      {
                        'fvAEPg' => {
                          'attributes' => {
                            'name' => 'WebTier'
                          }
                        }
                      }
                    ]
                  }
                }
              ],
              'attributes' => {
                'name' => 'test'
              }
            }
          },
          {
            'fvTenant' => {
              'attributes' => {
                'name' => 'test2'
              }
            }
          }
        ]
      }
    }

    mo = ACIrb::Loader.load_hash(hash)
    expect(mo.dn).to eq('uni')
    expect(mo.children[0].dn).to eq('uni/tn-test')
  end

  it 'Loads config similar to the ruby manifest' do
    hash = {
      'fvTenant' => {
        'attributes' => {
          'name' => 'test2',
          'dn' => 'uni/tn-test2'
        },
        'children' => [
          {
            'fvBD' => {
              'attributes' => {
                'name' => 'BD1'
              }
            }
          },
          {
            'fvAp' => {
              'attributes' => {
                'name' => 'WebApplication'
              },
              'children' => [
                {
                  'fvAEPg' => {
                    'attributes' => {
                      'name' => 'WebTier'
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }

    mo = ACIrb::Loader.load_hash(hash)
    expect(mo.dn).to eq('uni/tn-test2')
  end

  it 'Loads a non top object with dn defined' do
    hash = {
      'fvBD' => {
        'attributes' => {
          'name' => 'bd1',
          'dn' => 'uni/tn-test2/BD-bd1'
        }
      }
    }

    mo = ACIrb::Loader.load_hash(hash)
    expect(mo.dn).to eq('uni/tn-test2/BD-bd1')
  end
end
