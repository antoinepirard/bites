require 'sugar'

module.exports =
  env: 'static'

  templateData:
    site:
      title: 'Bites from Good Eggs'
      author: 'Good Eggs'
      url: 'http://goodeggs.github.io/bites'

      googleAnalytics:
        id: 'UA-26193287-5'

    getAuthor: ->
      @getCollection('authors')
        .findAllLive(author: @document.author)
        .first().toJSON()


  collections:
    posts: (database) ->
      database.findAllLive({relativeOutDirPath: 'posts'}, [date: -1])
    openSource: (database) ->
      database.findAllLive({relativeOutDirPath: 'open_source'}, [date: -1, title: 1])
    news: (database) ->
      database.findAllLive({relativeOutDirPath: 'posts', tags: {$has: 'news'}}, [date: -1])
    authors: (database) ->
      database.findAllLive({relativeOutDirPath: 'authors'})

  plugins:
    datefromfilename:
      removeDate: true
      dateRegExp: /\b(\d{4})-(\d{2})-(\d{2})-/
    cleanurls:
      trailingSlashes: true
    rss:
      collection: 'posts'
      url: '/rss'